# Troubleshooting

Where to start, how to split the path in half, what each signature means, and
what to do next. Statements resting on inference are marked **(inferred)** or
**(verify)**. Everything from "Triage" through "Counters and maps" is a read.
"Repair ladder" lists the mutations and what each costs.

## Ground rules

1. **Classify before you dig.** Decide which evidence layer you are in: desired
   state (CRs, slices), reconciled kernel state (routes, addresses, links),
   classifier state (eBPF maps and counters), or delivery (packets reaching a
   socket). A green layer says nothing about the next.
2. **Locate the failing connection stage first.** For a TCP connect failure,
   decide whether the SYN reaches the backend and the SYN-ACK reaches Envoy.
   Correlated captures can establish those boundaries. Aggregate counter deltas
   only suggest where to look. Other 503 causes need discovery, health,
   protocol or application checks.
3. **Two namespaces, two ifindex spaces.** A number copied from the pod netns is
   meaningless in the root netns.
4. **Compare event counters as deltas.** `drop_reasons` is per-CPU. Read before
   and after a controlled request, allow for background traffic and for resets
   on map replacement, and read slot 31 per CPU.
5. **Read-only first, mutations only with authorization.** A `kubectl debug`
   container, an ephemeral container or a privileged pod is a mutation. On
   production, get authorization before any `kubectl exec`, even for `/proc`
   reads.
6. **Record identity every time.** Context, UTC time, Envoy pod name and UID,
   node, sidecar image digest, VPC string, backend address, Envoy cluster name.
7. **Never force-reconcile Flux** to speed up a check. The infra repo forbids
   it. Wait for the interval and observe read-only.

Session variables used below:

```sh
CTX=datum-us-central-1-staging-lab     # explicit context, never change current-context
NS=datum-downstream-gateway
POD=envoy-datum-downstream-gateway-XXXXX
HOST=<node the Envoy pod runs on>
VPC=12                                 # base62 VPC string, as in the EndpointSlice
BACKEND=fd20:0:7::1:0:0                # the /128 Envoy is trying to reach
```

## Triage: what the Envoy symptom tells you

Envoy access logs are in the `envoy` container. The reviewed infra config uses
JSON, so parse `response_flags` instead of matching text. Flag meanings follow
the Envoy access-log documentation. They are symptoms, not root causes.

```sh
kubectl --context="$CTX" -n "$NS" logs "$POD" -c envoy --tail=200 \
  | jq -R 'fromjson? | select((.response_flags // "") | test("(^|,)(UF|UH|UR|URX|NR|DC|UC|UT)(,|$)"))'
```

| Signal | Means | Go to |
|--------|-------|-------|
| 503 `UF`, about 10 s | Upstream connection failure. 10 s was observed in the incident, not a universal default. Check the actual cluster connect timeout and transport failure reason, then locate the failed stage | The split, then the hop checklist |
| 503 `UF` well under 10 s | Something refused or reset the connect, or the socket could not be set up. Check for a VRF device that does not exist yet (`SO_BINDTODEVICE` fails) | P2 |
| 503 `UH` or "no healthy upstream" | No healthy upstream. Endpoints may be absent, unhealthy or ejected. Networking can cause health failures | P3 |
| 404 `NR` | No route matched in Envoy. Listener or route config, not Galactic | Check the HTTPProxy or HTTPRoute |
| 504 `UT` | Upstream request timed out. Does not prove the handshake or two-way delivery | P5 |
| `UC` or `UR` | Upstream connection termination or remote reset. The flag alone does not locate the cause | P5 |
| 200 for some backends, 503 for others | Per-backend fault: discovery, attachment or one stale entry | P4 |
| Worked, then 503 after a rollout or reload | Datapath reload, seed failure or wiped ADD-only maps | P6 |
| Small requests work, large transfers hang | MTU, loss, flow control or application behavior. Encap adds 40 bytes and `FIB_FRAG_NEEDED` sends no PTB | P7 |
| One edge works, another does not | Per-edge state (uplinks, return path, underlay) | P8 |

`DC` and `UF` alone do not identify an SRv6 fault. Confirm with the split.

## The split: did the SYN arrive, and did the SYN-ACK come back?

### Signal A: counters in the pod netns

Read the pod's netns from outside through `/proc`, using a pod with `hostPID` on
the same node. Multus has it in the reviewed labs **(verify on your cluster)**.
This is a read, but it is an `exec` into that pod.

```sh
M=$(kubectl --context=$CTX -n kube-system get pod -o wide \
      | awk -v n="$HOST" '/multus/ && $0 ~ n {print $1; exit}')
kubectl --context=$CTX -n kube-system exec $M -c kube-multus -- sh -c '
for p in /proc/[0-9]*; do
  [ "$(cat $p/comm 2>/dev/null)" = envoy ] || continue
  grep -q " ivs" $p/net/dev 2>/dev/null || continue
  echo "== $p  $(tr "\0" " " < $p/cgroup 2>/dev/null | grep -oE "pod[0-9a-f]{8}[_-][0-9a-f_-]+" | head -1)"
  grep -E "Ip6(InReceives|InDelivers|InNoRoutes|OutForwDatagrams)|Icmp6OutDestUnreachs|Icmp6OutMsgs" $p/net/snmp6
  grep -E "eth0|ivs|ivp|^ *G0" $p/net/dev | cut -c1-80
done'
```

Match the printed pod UID (dashes or underscores by cgroup driver, dashes on the
reviewed labs) to `$POD`'s `metadata.uid`, because a node can run several Envoy
processes. Take the numbers, send exactly one request, take them again.

| Delta during one failing request | Reading |
|----------------------------------|---------|
| `ivp<N>` RX rises, `eth0` TX rises | Consistent with outbound traffic crossing these interfaces. Capture the outer SID packet to establish encapsulation of this flow |
| `ivp<N>` RX rises, `eth0` TX flat | Investigate H5 and H6. Failure, other traffic or accounting may explain the mismatch |
| `ivs<N>` TX and RX flat | No interface evidence of traffic. Inspect binding, discovery and the attempted connection (H1 to H3) |
| `eth0` RX rises but `Ip6InDelivers` does not | If a capture independently identifies the reply, investigate return stage 2 (H13). Counters alone do not identify it |
| `Icmp6OutDestUnreachs` rises near failed attempts together with `Ip6OutForwDatagrams` | Consistent with the incident signature. Confirm the ICMP payload belongs to the failing flow and check H13 |
| `eth0` RX flat | No receive evidence. Investigate H8 to H12 and confirm with a flow-specific capture |

**The idle baseline is not zero.** On a healthy central Envoy pod (all eight
gateway local routes present, `Icmp6OutDestUnreachs` flat), `Ip6OutForwDatagrams`
still grew by about 16 and `Ip6InReceives` by about 36 in 30 s at idle, and
`Ip6InReceives` runs ahead of `Ip6InDelivers` by a large constant. The source of
that background forwarding was not identified. Never diagnose from
`Ip6OutForwDatagrams` or `Ip6InReceives` minus `Ip6InDelivers` alone. Use the
per-request delta of `Icmp6OutDestUnreachs` and the local-route check in H13.

### Signal B: eBPF drop counters on both nodes

Read `drop_reasons` on the edge node and on the compute node. The sidecar's
mounted bpffs exposes the same edge-node map, not a pod-specific set. Both
programs and unrelated flows update it.

| Movement | Reading |
|----------|---------|
| Compute `usid_ingress` entry counter rises, edge does not | Compute classifier executed for some traffic. Slot 33 increments before parsing and locator match, so this alone establishes neither arrival of this flow nor loss of its reply |
| Relevant real-Block `vrf_table.packets` rises | A packet matched that VRF classification. On compute use the backend's Argument. On edge use the advertised return Argument, not the pod-local synthetic one. Correlate with FIB and redirect observations |
| Neither node rises | No observed execution at those hooks. Check attachment, receiving interface, program and map identity, and flow captures before blaming the underlay |

### Signal C, when authorized: a packet capture

A capture inside the Envoy netns is the definitive picture. In the VPC 12
incident, `tcpdump -i any -n ip6` showed the decapsulated SYN-ACK tagged only
with the VRF device MAC, then five unanswered neighbor solicitations for the
gateway address, then an ICMPv6 destination-unreachable to the backend. An
ephemeral container is one path and is a mutation. An existing capable
inspection path may also work.

## Evidence strength

| Observation | Establishes | Does not establish |
|-------------|-------------|--------------------|
| BGP Established | Session established | Required route imported into the correct map or table |
| EndpointSlice Ready | Publisher's condition | Actual CNI attachment or application listener |
| `vrf_table.packets` increases | A recognized locator, function and Argument reached that classifier stage | Successful decap, forward or delivery |
| Redirect-success trace increases | Helper returned the expected redirect action | Packet received by peer or socket |
| SYN reaches backend | Forward path for that flow | Correct return route |
| SYN-ACK reaches Envoy `eth0` | Host return path reached the pod namespace | VRF-local socket delivery |
| HTTP 200 through one edge | That edge, backend and request succeeded then | Other edge or backend, large transfer, reload recovery |

## Hop-by-hop checklist

Follow the path in order and investigate the first independently verified
failed prerequisite. More than one fault may coexist. `N` is the pod table id
and `A` is the advertised VRFID.

```text
503 UF
 H1 Envoy cluster has endpoint + SO_BINDTODEVICE?          no -> P3
 H2 sidecar has VRF G<vpc9>V?                              no -> P2
 H4 backend /128 and default route in pod?                 no -> P2
 H5 capture shows encapsulated request?                    no -> H5/H6 (usid_egress fail open)
 H7 request reaches compute receiving interface?           no -> H7 (underlay, locator route)
 H9 backend gets SYN and replies?                          no -> H8/H9 (decap, FIB, attachment)
 H12 reply reaches edge and matches return VRF?            no -> H10/H11 (reply encap, underlay)
 H13 reply delivered to the Envoy socket?                  no -> H13 (stage 2, local route)
 yes: handshake delivered; look at later transport and application behavior
```

### H1. Envoy cluster and socket binding

- **True:** the cluster has the backend as an endpoint and, for a VPC backend,
  an upstream bind of `SO_BINDTODEVICE` to `G<vpc9>V`.
- **Check:** the cluster and endpoint config from Envoy (config dump or xDS
  through the admin interface if reachable; Envoy Gateway commonly binds it on
  localhost **(verify port)**) and the NSO extension server logs. Confirm the
  device name equals `G` + VPC zero-padded to 9 + `V`.
- **Fails as:** no bind config (tenant id unparseable, or VPC string over 9
  characters). An unbound socket can still enter the VRF through the main-table
  backend `/128` redirect. A missing named VRF prevents the intended bind.
  Inspect both paths.

### H2. Sidecar created the VRF and veth pair

- **True:** in the pod netns, `G<vpc9>V` with table `N`, `ivs<N>` enslaved,
  `ivp<N>` not enslaved, all UP.
- **Check:** `/proc/<pid>/net/dev` lists all three (snippet above). With shell
  access, `ip -d link show type vrf`.
- **Fails as:** none exist. The sidecar has not processed a slice for this VPC,
  crashed, or `EnsureVRF` keeps failing. Read the logs and metrics
  `galactic_ingress_sidecar_vrf_active` and
  `reconcile_errors_total{kind="ensure_vrf"}`.

### H3. The EndpointSlice the sidecar needs exists and is complete

- **True:** in the local cell API, a slice with the tenant label, the tenant
  annotation (`<vpc>-<attachment>`), the SID annotation and an IPv6 address.
- **Check:**

  ```sh
  kubectl --context=$CTX get endpointslices -A -l galactic.datum.net/tenant-id \
    -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,ADDR:.endpoints[0].addresses[0]
  kubectl --context=$CTX -n <ns> get endpointslice <name> -o yaml   # read the annotations
  ```

  The label key is as named in the source **(verify with `-o yaml`)**. Read the
  SID annotation from the YAML rather than guessing its key.
- **Fails as:** no slice (backend never attached, or the cell never received the
  projected copy); a label but no SID annotation (node had no locator or Node-ID
  yet, so the sidecar installs nothing and waits); the *first* endpoint is not
  the address you expect (only the first endpoint's first address is read).
- **Cross-cell:** if the backend exists in its home cell but not here, follow
  the cross-cell section in `datapath.md`.

### H4. Pod routes: backend redirect and VRF default

- **True:** main table has `<backend>/128 dev G<vpc9>V`. VRF table `N` has
  `default via <ivp<N> link-local> dev ivs<N>`. The gateway `/128` is on `ivs<N>`.
- **Check:** `ip -6 route show table main`, `ip -6 route show table N`,
  `ip -6 addr show dev ivs<N>`. Without a shell, read
  `/proc/<pid>/net/ipv6_route` (dest, dest-plen, src, src-plen, nexthop, metric,
  refcnt, use, flags, device; hex, dest as 32 digits):

  ```sh
  awk '$10 ~ /^(ivs|ivp|G0)/ {print $1, $2, $6, $9, $10}' /proc/$PID/net/ipv6_route
  ```
- **Fails as:** a missing main-table backend `/128` removes the fallback for
  unbound traffic (a correctly bound socket uses its VRF table directly). A
  missing VRF default breaks the normal route toward `ivp<N>`. Missing gateway
  assignment means checking actual source selection and return reachability.

### H5. `usid_egress` attached to `ivp<N>` and its keys resolve

- **True:** a TC ingress filter on `ivp<N>`; `ifindex_vrf_table[ivp<N> ifindex] =
  (ffff:ffff:ffff, N)`; `vrf_table[(ffff:ffff:ffff, N)]` exists;
  `node_src_addr_table[0]` is non-zero.
- **Check:** inspect `ivp<N>` attachments in the **pod netns** through an
  authorized path. Host-namespace `bpftool net show` does not show pod-local
  attachments. `tc filter show dev ivp<N> ingress` shows the TC filter, and
  `bpftool net show` also exposes tcx. Read shared pins with
  `bpftool map dump pinned /sys/fs/bpf/galactic/<map>`. `TRACE_IFINDEX_MISS` (23)
  rising means no `ifindex_vrf_table` row.
- **Fails as:** `usid_egress` fails **open and uncounted** when
  `node_src_addr_table` is zero (sidecar log "could not register this node's own
  SRv6 source address; egress routing will fail open"). The packet goes
  unencapsulated and the forward path is silently dead.

### H6. `egress_route_table` has the backend, with valid L2

- **True:** an LPM row for `(N, inet6, <backend>/128)` holding the backend SID,
  the pod's `eth0` ifindex, and the pod-side next-hop `dmac` and `smac`.
- **Check:** dump `egress_route_table`. Key: `prefixlen` (40 + prefix bits),
  table id (32 bits), family (8 bits), address (16 bytes). Value: SID,
  `link_ifindex`, `dmac`, `smac`.
- **Fails as:**
  - No row: `TRACE_MISS_ROUTE` (18) rises and the packet falls through
    unencapsulated. The sidecar could not resolve the SID (log `resolve link/L2
    for sid ...: no route to ...`): the pod's routing has no route to the
    backend node's locator, or it resolves out a non-uplink.
  - `link_ifindex == 0`: the local pass-through sentinel, so the packet is
    deliberately not encapsulated. Look for a shorter-prefix or stale
    pass-through row winning LPM.
  - Stale L2: the row exists but `dmac`/`smac` no longer match the next hop. The
    sidecar does not refresh L2 on a timer. Only `SetDesired` or a generation
    reapply rewrites it. Suspect this after a node, gateway or Cilium change.

### H7. Underlay carries the packet to the compute node

- **True:** the edge FIB has a route to the backend node's locator `/64`
  (Block + Node-ID), learned from the fabric over iBGP, and the packet leaves on
  the intended uplink.
- **Check (edge root netns):** `ip -6 route get <backend SID>`. On FRR,
  `show bgp ipv6 unicast <locator>/64` and `show ipv6 route`. Also the node's
  fabric-router ConfigMap.
- **Fails as:** no locator route, or a route that matches only a default via a
  management NIC (correctly encapsulated, then dropped by a gateway that never
  heard of the locator). Compute `usid_ingress` entry counter stays flat while
  the edge sends.
- **Two rules that cause silent failures:** the own-node locator must be a
  *local route on `lo`* and never an assigned address (an address can be
  published as a node address and absorbed into a tunnel mesh). The SRv6 `/48`
  must never be advertised over eBGP to the provider.

### H8. Compute `usid_ingress` classifies and decapsulates

- **True:** `usid_ingress` on the compute node's receiving uplinks (bond slaves
  included, since RX classification happens on the slaves and a VLAN tag arrives
  in `skb->vlan_tci`, which the program pops); `locator_table`, `function_table`
  and `vrf_table[(real block, A)]` populated for the backend's VRF.
- **Check:** counters below, `bpftool net show` for the filters (and whether
  another CNI's tcx program sits ahead of Galactic on the same hook), and the
  three maps.
- **Fails as:** entry counter flat (not attached on the receiving link, or a tcx
  program from another CNI decided the packet first, so Galactic reads a clean
  zero); `TRACE_ING_LOCATOR_MISS` (38) rising (locator not registered);
  `UNKNOWN_FUNCTION` (0) or `UNKNOWN_ARGUMENT` (1) rising (locator matched but
  the function or Argument row is missing, which is what a wiped ADD-only map
  looks like).

### H9. FIB lookup, redirect, and the backend receiving

- **True:** `bpf_fib_lookup` in the tenant VRF table finds the backend's
  host-side interface with a resolved neighbor, and the redirect is accepted.
- **Check:** slots `FIB_NO_NEIGH` (7), `FIB_UNREACHABLE` (8), `FIB_FRAG_NEEDED`
  (9), `FIB_LOOKUP_FAILED` (5), `FIB_NO_IFINDEX` (32), `REDIRECT_FAILED` (6). The
  tap or veth host end exists, is UP and is in the tenant VRF. The backend's
  neighbor exists (the FIB lookup never triggers discovery, so a resolved
  neighbor is required, though not necessarily permanent).
- **Fails as:** `FIB_NO_NEIGH` is the classic "route exists, nobody resolved the
  neighbor". `FIB_LOOKUP_FAILED` with no matching route lands in slot 5, so an
  empty tenant VRF looks like a generic lookup failure. Redirect success is not
  delivery. The backend's interface counters and the backend itself are the
  proof the SYN arrived.
- **Backend side:** confirm the address is on the backend, it listens on the
  port, and a VPC attachment exists. In the east echo incident the pod had only
  cluster addresses, no tenant slice, no advertisement and no tap, and
  everything upstream was healthy.

### H10. Backend reply is encapsulated toward the edge

- **True:** the compute `egress_route_table` has `(T, <gateway>/128)` with the
  edge's advertised return SID, installed by `galactic-router` from the
  gateway's EVPN Type-5 path, and `usid_egress` is attached to the backend's
  host-side interface.
- **Check:** the EVPN path for the gateway `/128` on the route reflector and the
  compute router (`BGPAdvertisement` exists with the right VRFID and route
  target). Dump the compute `egress_route_table`. `galactic-router` logs
  `installing route` and `route install failed`.
- **Fails as:** no gateway advertisement (see H11); route target mismatch (the
  compute node cannot find the tenant VRF); the path skipped because its
  next-hop is the router's own address; a compute row with the wrong Argument.

### H11. The gateway advertisement exists and is complete

- **True:** a `BGPAdvertisement` named `<vpcHex>-<Base62ToHex("ingress")>-<node>`
  with prefix `<gateway>/128`, `vrfID = A`, function `End.DT46`, community = the
  VPC route target, and annotations `ingress-host-ifindex` (> 0) and
  `ingress-host-mac`.
- **Check:**

  ```sh
  kubectl --context=$CTX -n galactic-system get bgpvrfinstances,bgpadvertisements
  kubectl --context=$CTX -n galactic-system get bgpadvertisement <name> -o yaml
  ```
- **Fails as:** advertisement missing (publication failed once and no later
  `SetDesired` retried; the sidecar logs "resolve this pod's host-side entry
  point" or a publish error and nothing retries on a timer); annotations missing
  or stale (the host installer skips quietly); the ifindex names an interface
  that no longer exists after a pod replacement (installer logs `Link not found`
  every 30 s); `spec.routerRef` not equal to the node name the host installer
  filters on.

### H12. Edge `usid_ingress`, stage 1 (root netns)

- **True:** the four facts in `datapath.md`: `locator_table` and `function_table`
  for the real Block and Node-ID; `vrf_table[(real block, A)]` to return table
  `0xF000 + A`; in that table a route `<gateway>/128 dev <host-side ifindex>`; a
  **permanent** neighbor `<gateway>` to the pod `eth0` MAC on that interface.
- **Check:**

  ```sh
  ADV=26                                         # spec.vrfID from the BGPVRFInstance
  printf 'return table = %d\n' $((0xF000 + ADV)) # for example 61466
  ip -6 route show table 61466                   # root netns, on the edge node
  ip -6 neigh show dev <lxc iface>               # PERMANENT entry for the gateway
  ```
- **Fails as:** `UNKNOWN_ARGUMENT` (1) means no `vrf_table` row for
  `(real block, A)`: the 30 s ticker has not installed it, the annotation is
  missing, or the wrong `A` is used (see the five numbers). `FIB_NO_NEIGH` (7)
  means the permanent neighbor is missing. `FIB_LOOKUP_FAILED` (5) means the
  return table has no route. A rising `vrf_table` `packets` proves only that the
  classifier matched.
- **Receiving link:** `usid_ingress` must be attached on the link the reply
  arrives on (bond slaves and VLAN-over-bond included). A wrong or incomplete
  override list means the entry counter never moves.

### H13. Stage 2, pod netns, ordinary kernel routing

- **True:** the reply lands on `eth0` (in no VRF). The main table has
  `<gateway>/128 dev G<vpc9>V`. Inside the VRF table the gateway is **local**
  (`RTN_LOCAL`). Both must hold.
- **Check the local route:** `ip -6 route show table all type local`, or from
  outside `/proc/$PID/net/ipv6_route`. A local route has flags `80200001`. A
  connected route has flags `00000001` and is **not** enough.

  ```sh
  awk '$1 !~ /^fe80|^ff00/ && $2=="80" && $10 ~ /^ivs/ {print $1, $6, $9, $10}' /proc/$PID/net/ipv6_route
  # healthy: each gateway shows BOTH  metric 00000000 flags 80200001  and  metric 00000100 flags 00000001
  # broken : only the flags 00000001 line
  ```

  `ip addr` showing the address, and an ordinary route dump, are not proof,
  because ordinary dumps hide local routes.
- **Fails as (VPC 12):** address present, `RTN_LOCAL` missing. The reply matches
  a connected route, is forwarded out `ivs<N>`, neighbor resolution for the pod's
  own address fails and ICMPv6 destination-unreachable is sent. Signature:
  `Icmp6OutDestUnreachs` grows with each failed request (and
  `Ip6OutForwDatagrams` with it), the gateway `/128` on `ivs<N>` shows only the
  `00000001` line, and neighbor entries for the gateway are `FAILED`. Use only
  the per-request delta.
- **Cause:** repeating `EnsureVRF` on a VRF whose gateway address had already
  completed DAD, when the code replaced the address. Fixed in galactic#623
  (`AddrAdd` only when absent). Any older sidecar is exposed.
- **Repair:** recreate the Envoy pod. The fix does not repair an address whose
  local route is already gone.

## Symptom playbooks

### P1. 503 `UF` at 10 s, all backends of one VPC

1. Do the split.
2. If the reply reaches the pod but is not delivered: H13. Check the local route
   on every VRF in the pod. If all show it missing, the cause is systematic (the
   sidecar version), not one VPC.
3. If the reply never reaches the pod: H10 to H12, in that order.
4. Confirm the sidecar image digest against the fixed build before naming any
   other cause:

   ```sh
   kubectl --context=$CTX -n $NS get pod $POD \
     -o jsonpath='{range .status.containerStatuses[?(@.name=="vpc-vrf-sidecar")]}{.imageID}{"\n"}{end}'
   ```

### P2. Sidecar never creates the VRF, or creates it incompletely

- Read the sidecar logs first.
- **Boot race:** the sidecar can start before `galactic-cni` pins the maps. Logs
  show `open pinned map ... no such file or directory`, and the address and route
  are already assigned. Errors stop once the maps exist. Confirm pins exist on
  the node, the sidecar mounts the host's bpffs, and the startup goroutine did
  not exit (P6).
- **Missing permissions:** the RBAC pre-flight checks only EndpointSlice watch.
  `forbidden` for `BGPVRFInstance` or `BGPAdvertisement` points at the Role
  binding for the service-account group.
- **No node name:** with `NODE_NAME` unset the log says return-path publishing is
  disabled. Envoy can send but replies have no route.
- **No gateway prefix:** with `GALACTIC_VRF_GATEWAY_PREFIX` unset the gateway
  address is not assigned and the publisher has no address to publish.

### P3. `UH` or no healthy upstream, or the backend is not in the cluster

- Inspect discovery, endpoint health, health-check failures and outlier
  ejection. Check H3 and the discovery section of `datapath.md`, but do not rule
  out a network failure that made existing endpoints unhealthy.
- A ready **route slice** for a Service is not the object the sidecar reads. The
  sidecar needs the CNI-published tenant slice. Envoy needs its own endpoint
  resource. Verify both.
- `Ready=true` on the tenant slice is a publication flag, not proof the
  attachment exists or the app listens.
- If the pod exists but has no tenant slice, no advertisement and no tap, the
  intended attachment is not evidenced. The CNI chain may have been skipped,
  failed partway, or had state removed later. Determine which from invocation
  logs, CNI cache and object history. Compare the pod's network status with its
  VPCAttachment, IPAM and NAD intent and read CNI and Multus logs from around pod
  creation. Startup ordering with Multus is a hypothesis, not an established
  cause.

### P4. Some backends work, some fail

Compare a working and a failing backend field by field at every hop:

| Compare | Working | Failing |
|---------|---------|---------|
| Tenant slice: label, annotation, SID, address | | |
| Sidecar route: `egress_route_table` row and L2 | | |
| Backend attachment: pod or tap, address, listener | | |
| Backend's node: locator route from the edge | | |
| Compute `usid_ingress` counters for that node | | |

A difference is a lead, not proof. Different nodes, SIDs and MACs are expected,
so check whether each value is correct for that backend. Typical findings: slice
missing or without SID; backend has no VPC address; the backend node's locator
route missing; a stale row after the backend moved nodes (its old SID is still in
the sidecar's route).

### P5. Connection succeeds, request fails at the application layer

A successful connection shows the handshake worked then. Later loss, MTU
problems, resets or path changes can still break delivery. Inspect application
logs, TLS and route config alongside transport errors, retransmissions and flow
captures. Do not exclude the datapath because setup succeeded.

### P6. It worked, then stopped after a rollout or reload

1. **Was the datapath reloaded?** A `galactic-cni` image roll, schema change or
   self-heal replaces the program and possibly all maps. The sidecar compares a
   generation string (`usid_egress` program id plus `egress_route_table` map id)
   every 5 s and reapplies on change.
2. **Is the sweeper running?** If the startup seed failed, `Inventory` and the
   sweeper never start, so reapply never happens. Look for `startup seed:` in the
   sidecar logs. If present, the process must restart to rerun startup after its
   cause is fixed. Restarting the sidecar process can do this. Replacing the
   whole Envoy pod is one option, not a requirement. Either is a mutation.
3. **Which registrations are missing?** CNI ADD registers locator, function and
   attachment-interface state. The host return ticker registers real-Block
   locator, function and VRF state for ingress returns. The sidecar writes its
   synthetic-Block and pod-interface rows. Recreated maps can leave real
   attachments unreachable until their registrations are restored. Host GC can
   repair missing `vrf_table` rows from live BGPVRFInstances and kernel VRFs, and
   the edge return loop registers its own state. Neither rebuilds every real
   attachment registration. Diagnose each map individually, and do not treat
   `UNKNOWN_ARGUMENT` as proof that recreating the attachment is the only fix.
4. **Generation does not cover everything.** It misses a lost `vrf_table`,
   `ifindex_vrf_table` or `node_src_addr_table` row on its own, and stale L2 in
   existing route values.
5. **Old program, new pins.** After a reload `ivp<N>` can reference the old
   program and maps for a while. Reattachment happens on reapply.

### P7. Small requests work, large ones stall

- The outer header adds 40 bytes. If decap FIB lookup returns `FIB_FRAG_NEEDED`
  the program drops the packet without building ICMP Packet Too Big. That drop
  gives no PTB feedback. Other underlay stages can behave differently, so
  correlate slot 9 with the affected flow instead of assigning every
  large-transfer failure to it.
- Test with `ping -6 -M do -s <size>` between tenant endpoints where possible,
  and watch slot 9 during a large transfer.

### P8. One edge works, another does not

- Run the hop checklist per edge and record which edge accepted the connection
  (a public hostname alone does not identify it).
- Typical per-edge faults: `usid_ingress` not attached on the actual receiving
  link (bond slaves, VLAN-over-bond, a per-node override missing), the edge's
  locator route missing at a peer, or its gateway advertisement stale.
- Another CNI's tcx program on the same interface runs before Galactic's clsact
  filter. Check `bpftool net show` for anything ahead of Galactic.

### P9. Slow first request, or intermittent first-packet failures

Observed after the fix on two test passes: some routes answered the first request
in about 2.2 s and about 0.14 s when retested hours later. **Not root-caused.**
Candidates, in order: neighbor resolution for the gateway or backend (the FIB
lookup never triggers discovery), the sidecar still completing setup (DAD takes
about 2 s on the reviewed kernels), and Envoy connection pooling. Measure before
changing anything.

## Counters and maps

Needs a host-level path with `BPF` capability and the **host's** bpffs. Another
pod's own `/sys/fs/bpf` is a separate empty instance. The sidecar mounts the host
bpffs but its image may lack `bpftool`.

```sh
# sum drop_reasons across CPUs (bpftool JSON shape varies by version; adjust the jq)
bpftool -j map dump pinned /sys/fs/bpf/galactic/drop_reasons \
  | jq -r '.[] | "\(.key)\t\([.values[].value] | add)"'
```

Method: dump and save with a timestamp; send exactly one request (or a fixed
count); dump again and subtract; ignore slots that did not change; treat slot 31
(`TRACE_ING_LAST_IFINDEX`) as a recorded value read per CPU; never sum all slots.

| Slot | Name | If it rises, look at |
|------|------|----------------------|
| 0 | `UNKNOWN_FUNCTION` | `function_table` row for (block, DT46) missing (wiped ADD-only map, or wrong node) |
| 1 | `UNKNOWN_ARGUMENT` | `vrf_table[(block, Argument)]` missing; wrong Argument (advertised vs pod-local) |
| 2, 3 | `MALFORMED_INNER`, `UNKNOWN_INNER_VERSION` | Corrupt or non-IP inner packet; MTU or GSO |
| 4 | `STRIP_FAILED` | Decap adjust-room or VLAN pop failed |
| 5 | `FIB_LOOKUP_FAILED` | No route in the resolved VRF table (also the code for an empty table) |
| 6 | `REDIRECT_FAILED` | Redirect returned something other than a redirect action |
| 7 | `FIB_NO_NEIGH` | No neighbor for the next hop; permanent neighbor missing |
| 8 | `FIB_UNREACHABLE` | Blackhole, unreachable or prohibit route |
| 9 | `FIB_FRAG_NEEDED` | MTU; no PTB sent |
| 10 | `UNEXPECTED_NEXTHDR` | Outer next-header is not 4 or 41 |
| 11 | `UNSUPPORTED_BEHAVIOR` | Function is not End.DT46 |
| 12, 14 | `EGRESS_ROUTE_ENCAP_FAILED`, `..REDIRECT_FAILED` | `usid_egress` could not encapsulate or redirect |
| 15 | `PUBLIC_UPLINK_REDIRECT_FAILED` | VIP-sourced reply path |
| 16 | `TRACE_MULTICAST_LL_BAIL` | Multicast or link-local destination deliberately not encapsulated |
| 17 | `TRACE_MISS_VRF` | `usid_egress` found no VRF row for the ifindex or table; fails open |
| 18 | `TRACE_MISS_ROUTE` | No `egress_route_table` match; fails open (H6) |
| 19 | `TRACE_PASSTHROUGH_ENTRY` | Matched a local pass-through row (`link_ifindex == 0`) |
| 21, 22 | `TRACE_REACHED_REDIRECT`, `TRACE_REDIRECT_OK` | Redirect attempted or helper accepted |
| 23 | `TRACE_IFINDEX_MISS` | Attachment interface has no `ifindex_vrf_table` row |
| 31 | `TRACE_ING_LAST_IFINDEX` | A recorded value, not an event counter |
| 32 | `FIB_NO_IFINDEX` | Lookup succeeded but returned no interface |
| 33 | `TRACE_ING_ENTRY` | `usid_ingress` ran at all **(verify)** |
| 34 to 37 | `TRACE_ING_*` pull, bounds, ethertype | Packet not parsed as IPv6; VLAN tag left in data on a NIC that does not offload it |
| 38 | `TRACE_ING_LOCATOR_MISS` | Packet reached the node but the locator is not registered |
| 39 | `TRACE_NDP_BAIL` | ICMPv6 neighbor discovery exempted from egress redirection |

Other useful reads:

- `vrf_table` per row: `packets`, `bytes`, `last_seen_ns`, `dropped_packets`.
  Matches minus `dropped_packets` is not proof of delivery.
- `bpftool net show` and `bpftool prog show`: which programs are attached where,
  including tcx links `tc filter show` cannot display.
- Compare the program and map ids an attached program references with the
  current pins after a reload (the generation the sidecar tracks).
- Decode map bytes with the C and Go layouts at the revision you run. Do not
  confuse base62 ids, kernel table ids, wire Arguments, byte order or map key
  prefix lengths.

## Log dictionary

Sidecar (`vpc-vrf-sidecar`):

```sh
kubectl --context=$CTX -n $NS logs $POD -c vpc-vrf-sidecar --tail=500
kubectl --context=$CTX -n $NS logs $POD -c vpc-vrf-sidecar --previous   # after a restart
```

| Log text | Meaning | What to do |
|----------|---------|------------|
| `startup seed: ...` | The initial uncached seed failed. `Inventory` and the sweeper never run for this process | Fix the cause, then restart the sidecar process or replace the pod through an authorized procedure |
| `open pinned map ... "vrf_table": no such file or directory` | Sidecar started before `galactic-cni` pinned the maps | Expected briefly at boot. If persistent, check `galactic-cni` health and the bpffs mount |
| `could not register this node's own SRv6 source address; egress routing will fail open` | This registration attempt failed. Inspect the map, since another writer or earlier attempt may have populated it. A zero source entry makes egress fail open | Check the node's `BGPRouter` (locator and Node-ID) and the pin, then H5 |
| `could not assign this VPC's own gateway address` | Address setup failed but the VRF may still be marked installed | Check `GALACTIC_VRF_GATEWAY_PREFIX`, the VRF slave and the address (H13) |
| `resolve this pod's host-side entry point` | The pod's `eth0` has no peer index or MAC yet, so the gateway advertisement was not published | Retries only on a later `SetDesired`. Check H11 |
| `resolve link/L2 for sid ...: no route to ...` | The pod cannot resolve the backend SID: no route to the remote locator, or it resolves out a non-uplink | Check H7 from the pod's point of view |
| `ingresssidecar: reapply VRF ...` (error) | A datapath-reload reapply failed for this VPC | Read the error. It retries next sweep |
| `VRF table ID changed on reapply` | The kernel gave the VRF a different table id | Investigate. The pod-local Argument changed |
| `failed to set sysctl (non-fatal) ... read-only file system` | The per-interface write failed. The init container configures defaults | Verify the init container completed and effective settings are right before calling it benign |
| Repeated bursts of `WARN failed to set sysctl` (**inferred**) | Sysctl writes happen when a VRF is created, which only runs when the VRF is absent, so this suggests VRFs being torn down and recreated, for example a slice that disappears and returns. Seen every ~10 min for hours on one production sidecar, cause not established | Compare with `vrf_teardown_pending` and slice churn, then check the gateway local route (H13) |

Host installer (`galactic-cni`):

| Log text | Meaning | What to do |
|----------|---------|------------|
| `Could not install the ingress sidecar's return path ... host-side interface N ... Link not found` | An advertisement points at an ifindex that no longer exists (a replaced pod) | Stale advertisement. Repeats every 30 s until cleaned up. Does not by itself break other VPCs |
| `GC: repaired missing eBPF vrf_table entry vrfInstance=...` | The 5-minute GC restored a lost `vrf_table` row | Note it: something wiped the map earlier |

`galactic-router`: `installing route` followed by `route install failed ...
resolve link/L2 for sid` means the compute router could not resolve the remote
SID (underlay or locator route missing). `errVRFNotInThisNetns` skip on the edge
is normal.

Metrics (sidecar, port 9182): a flat `reapply_total` after a known reload, or a
growing `reconcile_errors_total`, points to P6. Active-route metrics do not
verify kernel or map state.

## Known failures

Dated 2026-09-29. Confirm status before relying on a row.

| Failure | Signature | Cause | Status |
|---------|-----------|-------|--------|
| Gateway address lost its local route | 503 `UF` at 10 s on every VPC in an Envoy pod; `Icmp6OutDestUnreachs` rises per failed request; gateway `/128` on `ivs<N>` has only flags `00000001` | `AddrReplace` on an address that had finished DAD, rerun by `EnsureVRF` after a partial failure or a reload | Fixed in galactic#623 (main `7bc1c40`). Local source tags `v0.1.0`, `v0.3.0` and `v0.3.1` all use `AddrReplace`. The latest release inventory and running production image were not rechecked, so inspect release source and the deployed digest before stating exposure. Repair for an affected pod: recreate it |
| Startup seed aborts the goroutine | Log `startup seed:`; no reapply, no teardown for that pod | First `SetDesired` error (often maps not yet pinned) returns from the goroutine | Open, tracked separately |
| Backend pod has no VPC attachment | No tenant slice, advertisement or tap; pod has only cluster addresses; a route slice still claims ready | Not established. Multus startup timing is a hypothesis only | Recovered by recreating the pod; cause unknown |
| Stale ingress advertisements | Installer logs `Link not found` every 30 s | An old pod's ifindex remained in an advertisement | Noise for other VPCs. ifindex reuse and retained neighbors are a hazard |
| Sidecar route L2 goes stale | Packets leave with wrong `dmac`/`smac`; forward path fails after a node or gateway change | Sidecar never re-resolves L2 on a timer | Design gap, open |
| Missing registrations after a schema change | Classification or attachment-map misses for previously healthy backends | New pins lack prior registrations; recovery coverage differs by map | GC repairs eligible `vrf_table` rows; the return loop repairs its own state. Other registrations need an explicit recovery plan |
| Cilium tcx runs before Galactic | Galactic counters read a clean zero while traffic fails | tcx programs on the same hook run before clsact filters | Check `bpftool net show` |
| Earlier 503 incidents with the same symptom | Egress-route and reload issues | | Historical |

## Repair ladder

Do not skip steps. Verify after every one.

| Level | Action | Cost | When |
|-------|--------|------|------|
| 0 | Read-only diagnosis | None | Always first |
| 1 | Wait one interval (5 s sweeper, 30 s return ticker, 5 min GC) | None | After a fix that should self-heal. Do not force a Flux reconcile |
| 2 | Restart the sidecar process or replace the affected Envoy pod, according to the diagnosis | A process restart keeps the pod netns. Pod replacement rebuilds it and briefly interrupts the node's ingress | A process restart can recover the seed and sweeper startup path after its cause is fixed. It does not guarantee repair of a missing local route. Pod replacement was the documented incident recovery. Get authorization |
| 3 | Recreate the affected **backend pod** | That workload restarts | Missing VPC attachment |
| 4 | Roll the `galactic-cni` DaemonSet on a node | Datapath reload, and the sidecar reapplies. Safe only if no map schema changed | Attach problems, stale programs. Never on production without a plan |
| 5 | Fix the source and release | Production agents follow the newest release automatically | Real defects |

Never do these by hand: delete or edit pinned maps, delete routes in the reserved
return-table range `0xF000` to `0xFFFF`, flush a VRF table, or force a Flux
reconcile. If you must change state to test a theory, do it in staging, record
the before and after, and put it back.

## Verify a repair

Run all of these on each affected edge after any repair, and record them.

1. Sidecar image digest is the intended one (P1 step 4).
2. Every `ivs<N>` gateway address shows both a local route (flags `80200001`) and
   the connected route (H13).
3. `vrf_table` rows exist for the sidecar Argument (synthetic block) and, on the
   host, for the advertised Argument (real block) to `0xF000 + A`.
4. The return table has the gateway `/128` and a permanent neighbor whose MAC
   equals the `ingress-host-mac` annotation.
5. One request per backend through that edge returns the expected content, with a
   before and after counter delta that shows the flow.
6. Sidecar `reconcile_errors_total` is flat and there is no new `startup seed:`.
7. The result holds after the next reload or restart of `galactic-cni`, if that
   is part of the claim. That test is a change and needs authorization.

For an end-to-end matrix, test each backend through **each ingress edge** and
record which edge accepted the connection and which backend answered, so
central to central, central to east, east to central and east to east are
distinct. A deliberately targeted listener or port-forward can isolate an edge
but bypasses parts of public ingress. It does not validate public DNS, VIP
advertisement or external load balancing. Large-transfer, restart and deliberate
reload tests are separate work needing authorization.

## Cheat sheet

```sh
printf -v pad '%9s' "$VPC"; echo "G${pad// /0}V"  # VRF device name, for example G000000012V
printf 'return table = %d\n' $((0xF000 + ADV))    # ADV = spec.vrfID of the BGPVRFInstance
```

| Object | Namespace | Command |
|--------|-----------|---------|
| Envoy pod, sidecar image | `datum-downstream-gateway` | `kubectl get pod -o wide`, `jsonpath` on `imageID` |
| Tenant EndpointSlices | The workload's own namespace | `get endpointslices -A -l galactic.datum.net/tenant-id` |
| BGPRouter, BGPVRFInstance, BGPAdvertisement, BGPPeer | `galactic-system` | `get bgprouters,bgpvrfinstances,bgpadvertisements,bgppeers` |
| Node agents | `galactic-system` | `get pods -o wide`, `logs -c ...` |
| Fabric routers (FRR) | `galactic-system` | `logs`, `exec` into `fabric-router` for `vtysh -c 'show bgp summary'` |
| Multus (for `/proc` reads) | `kube-system` | Pod on the same node as the Envoy pod |
| Flux state | `flux-system`, `galactic-system` | `get kustomization`, `get ocirepository` |

Five questions that resolve most tickets:

1. Which digest is the sidecar running, and is it a build with the local-route
   fix?
2. Does the failing backend have a tenant slice, an advertisement and an address
   on the backend itself?
3. Does the gateway `/128` have a local route inside the VRF?
4. Which side of the split is silent: the forward path or the return?
5. Did anything reload the datapath just before it broke?

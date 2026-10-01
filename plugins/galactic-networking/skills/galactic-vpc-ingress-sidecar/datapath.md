# Datapath: Forward, Return, Discovery, Cross-Region

## 1. How Envoy ends up bound to the VRF

1. An `HTTPProxy` rule has a vpcPod or instance backend.
2. NSO and Envoy Gateway generate the cluster
   `httproute/{dsNS}/{proxy}/rule/{idx}`.
3. The extension server maps downstream to upstream namespace and consults the
   VPC backend index (`idx.VPCPods`: EndpointSlice tenant-id to device
   `G%09sV`, byte-identical to `intf.GenerateInterfaceNameVRF`).
4. It replaces the cluster's `UpstreamBindConfig` with a `BindConfig` carrying a
   socket option: level `SOL_SOCKET` (1), option `SO_BINDTODEVICE` (25), the VRF
   name as bytes (base64 in JSON), state `STATE_PREBIND`. It sets no explicit
   source IP. Linux source selection and the gateway address on the VRF slave
   supply the inner source.
5. Envoy calls `socket()`, `setsockopt(SO_BINDTODEVICE, "G{vpc9}V")`,
   `connect(backend)`.

If the tenant id is unparseable or the VPC string exceeds 9 characters, the
cluster is left **unbound**. Binding to a guessed name would fail every
connection. An unbound socket can still enter the VRF through the main-table
backend `/128` redirect. If the named VRF device is missing, the intended bind
cannot complete, so inspect Envoy's socket and connect errors. A sidecar that
has not processed the slice, or crashed, looks like this.

For NetworkService backends, the index joins generated route-slice addresses to
Galactic tenant slices. Resolved addresses must agree on the VPC. Unresolved
addresses are skipped and conflicting resolution is rejected. The join is keyed
by canonical IP, not Kubernetes namespace. That is an implementation constraint
for overlapping addresses, not proof of a collision.

Inspect the actual Envoy cluster config rather than inferring the bind from a
route's existence.

Sources: NSO `internal/extensionserver/mutate/vpcpod.go`,
`internal/extensionserver/cache/index.go`, the tenant-labelled branch in
`internal/controller/gateway_controller.go`.

## 2. Forward path: Envoy to the backend

1. Envoy connects to the backend `/128` with the socket bound to the VRF.
2. Lookup in VRF table N hits `default via <ivpN link-local> dev ivsN`. The
   source address is the only global address on `ivsN`, the gateway `/128`.
3. The packet goes out `ivsN` and arrives on `ivpN` RX, where TC ingress runs
   `usid_egress`.
4. `ifindex_vrf_table[ivpN]` gives `(ffff:ffff:ffff, N)`, then `vrf_table` gives
   table id N.
5. It bails on multicast or link-local destinations and on ICMPv6 ND types
   133 to 137.
6. LPM in `egress_route_table` for `(N, inet6, backend/128)` hits.
7. It takes the `node_src_addr_table` base (non-zero) and splices Argument N
   into bits 69 to 80.
8. `bpf_skb_adjust_room` +40 (MAC mode, `ENCAP_L3_IPV6`), outer header:
   src = node SID base (Arg N), dst = backend SID, hop limit 64, nexthdr 41.
9. Ethernet dst and src come from the pre-resolved `dmac`/`smac`.
   `bpf_redirect(link_ifindex = eth0)`.
10. The host FIB routes the backend's locator (learned over the BGP underlay)
    out the uplink. The fabric routes it to the compute node.
11. Compute `usid_ingress`: `locator_table` hit, `function_table` DT46,
    `vrf_table[(block, Arg)]` gives tenant table T. It strips the outer header,
    runs `bpf_fib_lookup` in table T (TBID), then redirects to the host-side
    veth (`bpf_redirect_peer`) or tap (`bpf_redirect`).
12. The backend sees the inner packet: src = gateway `/128`, dst = backend.

Notes on the hops:

- **Source address.** NSO sets no explicit source. The intended route and source
  selection uses the gateway `/128` on `ivsN`, and past successful requests
  showed that address at the backend. If address setup fails or other addresses
  appear, verify the selected source rather than assuming.
- **`link_ifindex` and MACs are pod-namespace values.** The sidecar resolves
  them in the pod netns (`RouteGet(sid)` must exit via an interface in
  `attach.UplinkIndexes()`, which is `eth0` in the pod). A route resolving out
  any other link is **rejected**. Otherwise a management NIC's default route
  would "resolve" a SID the fabric has not advertised, producing a correctly
  encapsulated packet on a network that never heard of the locator.
- **`autoDetectInterfaces` skips VRF slaves**, so the internal veth default
  route is never mistaken for the transport uplink.
- **Redirect is `bpf_redirect(eth0)`, same namespace.** Only the ingress side
  needs `bpf_redirect_peer`.
- **NDP carve-outs.** ND is host-local signalling with a directly attached peer.
  The multicast and link-local bail (`ff00::/8`, `fe80::/10`) and the ICMPv6
  type 133 to 137 bail (a solicited NA is unicast) keep it out of
  `egress_route_table`.
- **Plain header push, not an SRH.** One segment, so reduced encap omits the
  SRH. The kernel `seg6` lwtunnel is not used because its `dst_cache` is reused
  across input and output resolution paths whose routing contexts differ under
  per-tenant VRFs.
- **Outer source = node SID base with the pod-local table id as Argument.**
  That is not the gateway's advertised return Argument and could numerically
  coincide with a real row. Backend replies target the **inner gateway
  address**, whose EVPN route supplies the correct return SID. A design that
  reflects the request's outer source as a reply SID needs a separate contract.
- **MTU and GSO.** Encapsulation adds 40 bytes. The program handles GSO
  adjustment. Decapsulation reports `FIB_FRAG_NEEDED`, a drop that builds no
  ICMP Packet Too Big. A small successful request establishes nothing about
  large-packet reliability. Cilium hook traversal after the pod redirect is
  outside the Galactic source and must be observed separately.

## 3. Return path: backend reply back to Envoy

Two stages in two namespaces, each with its own decision.

### Compute side

1. The backend sends SYN-ACK, src = backend, dst = gateway `/128`.
2. Compute host-side `H` runs `usid_egress`: LPM `(T, gateway/128)` finds the
   row `galactic-router` installed from the EVPN path.
3. Encap: src = compute SID (Arg = compute VRFID), dst = **edge SID**
   (edge block : nodeID : E : advertised VRFID).
4. Redirect out the uplink with pre-resolved L2. The fabric routes it to the
   edge.

### Stage 1: edge root netns (eBPF)

1. `locator_table[(block, nodeID)]` hit (registered by `ensureSidecarReturnPath`).
2. `function_table[(block, DT46)]` hit.
3. `vrf_table[(REAL block, advertised VRFID)]` gives return table `0xF000 + A`.
4. Strip the outer header.
5. `bpf_fib_lookup(TBID = 0xF000 + A)` finds route `gateway/128 dev HVE` plus a
   permanent neighbor `gateway -> pod eth0 MAC`.
6. `ifindex_egress_kind_table[HVE]`: a miss uses `bpf_redirect`, which is safe
   for a veth (it transmits on the host end and the veth driver forwards to the
   peer). VETH uses `bpf_redirect_peer`, which crosses into the pod netns.
7. The packet arrives on pod `eth0` RX.

#### The four facts stage 1 needs (host installer)

`ensureSidecarReturnPath` (`internal/installer/sidecarreturn.go`) runs on a 30 s
ticker (`sidecarReturnReconcileInterval`), non-fatal to the installer.
Overlapping ticks are skipped.

1. It lists `BGPAdvertisement`s in the namespace and keeps those with
   `spec.routerRef == this node`, a name ending `-{Base62ToHex(ingress)}-{node}`,
   and a VRFID. They are identified by **name**, not shape, because a real CNI
   attachment's advertisement looks identical (/128, Argument, DT46) and must
   not be touched.
2. It parses annotations `ingress-host-ifindex` (> 0) and `ingress-host-mac`.
   Otherwise it skips quietly (the sidecar has not recorded it yet).
3. **Prune first**, even with zero endpoints: delete IPv6 routes in
   `[0xF000, 0xF000+0xFFF]` not in the live set. With no endpoints, return.
4. It reads `nodeLocatorIdentity` from the `BGPRouter` (none means return and
   let the ticker retry), then registers `locator_table` and `function_table`.
5. Per endpoint: `LinkByIndex(hostIfindex)` must exist, then
   `RouteReplace` in table `0xF000+A` for `gateway/128 dev hostIfindex`, then
   `NeighSet NUD_PERMANENT gateway -> pod eth0 MAC`, then
   `vrf_table[(REAL block, A)] = {table, EgressKindVeth}`.

Why each piece exists:

1. **locator and function entries** for the node's real Block and Node-ID. An
   edge node may have no tenant CNI attachment to register them, and
   `usid_ingress` would otherwise pass every arriving uSID packet to a stack
   with no tunnel device (the kernel counts `Ip6InHdrErrors`).
2. **`vrf_table` under the real Block**, keyed on the advertised VRFID, pointing
   at a table this file owns. This differs from the sidecar's synthetic rows.
3. **A route out the host-side veth**, so `bpf_fib_lookup` yields an interface
   `bpf_redirect_peer` can cross.
4. **A permanent neighbor**, because `bpf_fib_lookup` never triggers NDP and an
   unresolved neighbor is a silent drop (`FIB_NO_NEIGH`).

The reader filters `spec.routerRef.name == nodeName`. The publisher writes the
matched BGPRouter object's name. They must agree in the deployment.
`LinkByIndex` verifies existence, not that a reused ifindex is still the
advertised pod's peer. Errors are collected per endpoint and do not stop the
others.

A comment in `installSidecarReturn` says `EgressKindVeth` is "a real claim here"
and plain `bpf_redirect` would never reach the sidecar. In the current
datapath `vrf_value.egress_kind` is not read, and step 9 keys on
`ifindex_egress_kind_table[resolved ifindex]`. The installer does not register
the host-side veth there, so without another writer you get a miss and a plain
`bpf_redirect`, which still delivers. The incident notes report that registering
the ifindex as VETH made `redirect_peer` fire and changed nothing. That rules
out the hypothesis for that incident, not every future fault.

### Stage 2: pod netns (plain kernel, no eBPF)

The reply lands on `eth0`, which is in no VRF, so input lookup uses the **main
table**. The gateway address is assigned to `ivsN`, which is enslaved to the
VRF, so it is "local" only in the VRF's own table. Without help the main-table
lookup finds nothing local and drops silently: `Ip6InReceives` advances,
`Ip6InDelivers` does not, and no error counter moves.

The help is `ensureGatewayVRFRoute`, a main-table `/128` route at the VRF
device. The VRF driver then redoes the lookup in the VRF table, where the
address should resolve as `RTN_LOCAL`, and the packet reaches the bound socket.

Everything depends on that `RTN_LOCAL`. The kernel installs it when an address
finishes DAD. If it is missing, only the connected unicast route matches. The
kernel forwards out `ivsN`, tries neighbor resolution for the pod's **own**
address, sends five unanswered NS and then an ICMPv6 destination-unreachable to
the backend. Envoy never sees the SYN-ACK and the connect times out
(`UF` at about 10 s, then 503).

## 4. Endpoint discovery: two contracts

Envoy endpoint discovery and sidecar route discovery are related but separate.
A Service-derived route slice with a ready backend does not satisfy the sidecar
contract.

| Consumer | Needs | Does |
|----------|-------|------|
| Galactic sidecar | Tenant label exists; annotation parses as VPC/attachment; SID annotation; IPv6 address type; first endpoint's first address | Installs one backend `/128` toward that SID in the VPC table |
| NSO Instance backend resolution | The CNI-published slice named by the Instance backend and its tenant label | Uses the direct VPC-pod branch before synthesized-Service handling |
| NSO NetworkService binding index | Service-derived route addresses joined to tenant slices by canonical address | Identifies the VPC for the rule's upstream bind |
| Envoy endpoint discovery | The generated backend or route endpoint resources | Picks upstream address and port. It does not program Galactic BPF routes |

`BuildDesiredRoute` ignores ports, target references, and the `ready`,
`serving` and `terminating` conditions. It uses only the first endpoint and
first address. Its SID check is `net.ParseIP`, and actual registration applies a
stricter IPv6 check. A missing SID is a no-route result. A malformed selected
slice is logged and skipped, which can leave the previous desired route in
place. A missing object reaches `SetDesired(key, nil)` and starts teardown
grace.

The controller's predicate is tenant-label existence while route translation
parses the **annotation**. Keep both consistent. Do not assume removing the
label alone withdraws a route. Validate the delete and reconcile path.

## 5. Cross-cell propagation of backend information

```
Backend cell CNI ADD -> per-pod tenant EndpointSlice + SID
  -> NSO VPC EndpointSlice writeback -> hub copy vpc-<location>-<sourceName>
  -> Karmada nso-resources propagation -> gateway cell's local API (projected slice)
  -> galactic-vrf: backend /128 to remote SID
  -> NSO binding index: endpoint address to VPC -> Envoy SO_BINDTODEVICE
```

- NSO's `vpcendpointslice_writeback.go` reads locally published tenant slices
  and writes hub copies. It skips already projected slices and
  `karmada.io/managed` resources to avoid feedback. Names start
  `vpc-<location>-<sourceName>`, truncated with a hash suffix when too long.
  It preserves addresses, conditions, ports and annotations (including SID and
  tenant id), adds projection, location and routing metadata, and drops the
  source Pod owner reference. The hub object uses the source namespace, so
  correct namespace federation and routing metadata is a prerequisite.
- `EdgeReachability` influences eligibility. A known record with no relevant
  intersection causes cleanup. A missing record does not by itself prevent
  publication. An empty source endpoint list does not immediately overwrite the
  old copy. There is a one-minute resync and a ten-minute stale-copy sweep.
  These are reconciliation intervals, not convergence guarantees.
- Infra's federated `nso-resources` ClusterPropagationPolicy uses `Overwrite`
  conflict resolution, targets gateway-enabled cells and includes EndpointSlices
  with an `upstream-cluster-name` label. When a backend exists in its home cell
  but is missing on the receiving edge, inspect the rendered policy, projected
  objects and federation status.
- The sidecar watches the **local cell API**. It does not query the remote
  backend cluster, interpret a region field, learn a SID from BGP, or fall back
  to an address in a different region.

### Same region versus cross region

| Stage | Same region | Cross region |
|-------|-------------|--------------|
| Backend discovery | Local or projected tenant slice in the edge API | Projected remote slice in the edge API |
| Envoy socket | Bound to the backend VPC device | Same |
| Sidecar lookup | VPC table + backend `/128` to SID | Same lookup with remote compute SID |
| Underlay forwarding | Fabric routes the compute locator | Inter-region fabric routes the compute locator |
| Compute delivery | Decap into host tenant VRF, forward to attachment | Same |
| Return lookup | Tenant VRF route for the originating edge's gateway `/128` | Same, with remote edge SID |
| Edge delivery | Decap into return table, host veth, pod VRF-local socket | Same |

A request entering central for an east backend is encapsulated toward the
**east compute SID**. It does not need an extra decap and encap through an east
Envoy. The return target is the gateway address of the **originating** Envoy
pod's VPC. Actual transit hops depend on underlay routes and must be measured.
An EVPN route reflector is a control-plane participant, not a packet waypoint.

The compute router imports best EVPN Type-5 paths, uses route targets to find a
host VPC VRF and writes an egress-map entry. It takes the SID from the
Prefix-SID attribute, with an MP_REACH next-hop fallback. Own paths are skipped.
A VPC that exists only inside an edge pod is not a host VRF, so
`errVRFNotInThisNetns` is an ordinary skip there. Withdrawals remove routes.
Import and write errors are logged, and an established BGP session alone does
not prove the intended map row exists. Source:
`internal/runtime/gobgp/monitor.go`, `internal/plumbing/srv6/egress.go`.

## 6. Container and hypervisor attachment

The compute-side terminal interface can be a veth or a tap. For a veth,
`ifindex_egress_kind_table` can select `bpf_redirect_peer`. For a tap, normal
redirect transmits into the tap and runtime path. Both use the host VPC VRF and
Galactic attachment registration.

`galactic-tap` creates the host-side VRF and tap, consumes IPAM when configured,
configures the host gateway, records router-advertisement state, and can write a
Kata direct-assignment-networking file on request. The runtime supplies the
guest side. A tap is not a veth into a Linux pod netns, so pod status addresses
alone are insufficient for a microVM. Correlate CNI results, attachment
interfaces, BGP publication, IPAM, runtime metadata and guest observations.

Sources: `internal/cnitap/{ops_add,dan}.go`, `internal/cnibgp/{ops_add,bgp}.go`.

## 7. Shared maps, namespace boundaries, repair coverage

### What is shared and what is local

The sidecar mounts host bpffs and opens the same pins as the host installer and
router. Links, routes, VRF devices, ifindexes and neighbor resolution stay
namespace-local.

The synthetic Block separates sidecar **VRF keys** from real-Block host keys. It
does not make the map set namespace-safe:

- `ifindex_vrf_table` and `ifindex_egress_kind_table` have raw ifindex keys. The
  same number can identify different interfaces in different namespaces.
- `egress_route_table` keys include table id, family and prefix but no namespace
  id. Its values hold namespace-local ifindex and MACs.
- Every sidecar netns starts VRF allocation independently, so
  `(synthetic Block, table id)` does not distinguish two sidecar pods on one
  node.
- Main-table backend redirect routes inside one Envoy netns are keyed by
  destination prefix, not VPC. They cannot represent two different VRF redirects
  for an identical backend prefix.

These are structural constraints visible in the keys, not observed causes of an
incident. The DaemonSet shape normally limits Envoy to one pod per eligible
node. That does not prove safety against host and pod numeric collisions or
every replacement and overlap scenario. **Do not add a second sidecar pod per
node on the assumption that the synthetic Block isolates namespaces.**

### Why the host skips sidecar route refresh

`egressroutemap.Register` resolves the SID in the writer's namespace:
`RouteGet(SID)`, first route, permitted uplink, link source MAC, next-hop
neighbor MAC (the route gateway if present, otherwise the SID). An unresolved
neighbor triggers a UDP6 probe to port 9 and bounded polling (up to 2 s at
100 ms). The lookup requires a matching IP and a six-byte MAC and does not
validate neighbor state. The route is rejected if it resolves outside
`attach.UplinkIndexes()`. The datapath then uses the stored link and MACs
without re-resolving per packet.

Every 30 s the host installer refreshes eligible egress routes. It first derives
sidecar-owned table ids from synthetic-Block VRF rows and skips them. If it
cannot determine ownership it skips the refresh rather than rewrite pod values
from the host namespace. The exclusion is numeric, so a coincident host table id
is also skipped.

The sidecar has no equivalent periodic L2 refresh at this revision. It rewrites
a route only during `SetDesired` or a generation-triggered reapply. A neighbor,
next-hop or pod route change that causes neither can leave cached sidecar link
and L2 stale. Host uplink watching does not repair that row.

### Uplink watching

`attach.ResolveInterfaces` honors `GALACTIC_CNI_EBPF_INTERFACES` or detects
default-route and BGP-route interfaces, excluding loopback, WireGuard and VRF
slaves. Bond expansion includes masters and slaves, including supported
VLAN-over-bond cases. `attach.StartWatching` subscribes to link and route
updates, debounces, re-resolves, reattaches desired hooks and detaches removed
ones, and invalidates the uplink-index cache (TTL 15 s). Detection can still
choose an incomplete set, so verify the hooks and any override. The central
cluster source has a node-specific `bond0,bond1` override for
`edge-20a211-us-central-1`.

Sources: `internal/plumbing/ebpf/egressroutemap/{egressroute,owner}.go`,
`internal/installer/installer.go`, `internal/ingresssidecar/store.go`,
`internal/plumbing/ebpf/attach/{interfaces,uplinks,watch}.go`.

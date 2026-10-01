# Control Plane: How State Reaches Where It Must Be

Sources: `internal/cnibgp/{ops_add,bgp,endpointslice}.go`,
`cmd/galactic-vrf/root.go`, `internal/ingresssidecar/{seed,store,controller,backend,ebpfdatapath,gatewayaddress}.go`.

## 1. A backend VPC pod is attached (CNI ADD)

The sidecar's forward path depends entirely on the EndpointSlice produced here.

1. kubelet calls the master plugin (`galactic-veth` or `galactic-tap`). It
   creates the host VRF `G{vpc}V` if absent (shared per VPC per node), creates
   the veth `H/G` or tap, and enslaves the host end into the VRF.
2. `galactic-ipam` allocates the IPv6 address (and optional IPv4).
3. `galactic-bgp` (chain tail) lists `BGPRouter`s and matches
   `spec.targetRef.name` to this node.
4. It allocates the Argument: lowest free VRFID in [1..0xFFF]. An existing
   `BGPVRFInstance` keeps its value.
5. It `CreateOrUpdate`s `BGPVRFInstance {vpcHex}-{node}` with RT
   `ASN:uint32(vpcHex)` for import and export, then runs `checkArgumentCollision`
   for two first attachments racing.
6. It computes `sid = ComputeSID(locator, nodeID, VRFID, End.DT46)`.
7. It writes host maps: `locator_table`, `function_table`, `vrf_table[(block, VRFID)]`,
   `ifindex_vrf_table[H]`, `ifindex_egress_kind_table[H]` (VETH or TAP), a
   pass-through `egress_route_table` row for the pod prefix, and
   `node_src_addr_table` and `public_uplink_table` (non-fatal). It attaches
   `usid_egress` to `H`.
8. It `CreateOrUpdate`s `BGPAdvertisement {vpcHex}-{attachmentHex}-{node}`
   (EVPN Type-5, prefix = pod subnet, VRFID, End.DT46).
9. It publishes the EndpointSlice in the **pod's namespace**: label and
   annotation tenant-id `{vpc}-{att}`, annotation `srv6-sid`, address = pod
   IPv6, `ready=true`, ownerRef = Pod.
10. `galactic-router` watches the advertisement and emits an EVPN Type-5 path
    with the Prefix-SID and RT.

Notes:

- The slice is a separate step after the CRDs. No IPv6 IPAM result means no
  slice (a tap with its own addressing, for example).
- The SID in the slice equals the SID `galactic-router` advertises. Both sides
  compute it independently with `srv6.ComputeSID` from the same inputs.
- A slice can exist **without** the SID annotation (the node had no locator or
  node id yet). `BuildDesiredRoute` returns `nil, nil` and the route appears on
  a later update.
- `Ready=true` records publication by the CNI. It is not an application health
  probe or a check that the attachment still exists.
- The CNI refuses to take over an existing unlabelled slice.

## 2. Sidecar startup

1. Init container `vpc-vrf-sysctl-init` (privileged, one-shot) runs in the pod
   netns before any VRF exists. It writes `net.{ipv4,ipv6}.conf.{default,all}.forwarding=1`,
   `rp_filter=0`, `proxy_arp/ndp=1`. `default.*` is inherited by every VRF and
   veth created later. Per-interface writes from the sidecar fail because
   `/proc/sys` is read-only there.
2. The sidecar starts (caps `NET_ADMIN` and `BPF`, uid 0, read-only rootfs).
   Config: `NODE_NAME`, `GALACTIC_VRF_GATEWAY_PREFIX`, grace 30 s, sweep 5 s,
   metrics `:9182`.
3. It builds a controller-runtime manager (BGP types on the scheme) and runs
   `checkWatchPermissions`, an RBAC pre-flight for EndpointSlice watch only.
4. If `NODE_NAME` is set: it installs the gateway publisher
   (`k8sGatewayPublisher`, `NetlinkGatewayAddressResolver`), the node-source
   resolver (reads `BGPRouter`), and, if the prefix is set, gateway address
   assignment. If `NODE_NAME` is empty, return-path publishing is disabled and
   the log says so.
5. It registers a reconciler on EndpointSlices that carry the tenant-id label.
6. In parallel:
   - the manager lists and watches EndpointSlices cluster-wide, and each
     reconcile runs `BuildDesiredRoute` then `SetDesired`;
   - a startup goroutine runs `SeedFromAPI` (an **uncached** list of labelled
     slices) calling `SetDesired` for each slice with a SID, then `Inventory`
     (adopts kernel state not claimed by a live slice, `absentSince = now`, 30 s
     grace), then starts `RunSweeper` every 5 s.

Why seed before inventory: waiting for cache sync guarantees only that the
informer's list is in the cache, not that the workqueue it fed has drained.
Without seeding first, Inventory could see a live pod's kernel route as
orphaned, adopt it under a synthetic `boot/<vpc>/<prefix>` key with its own
grace, and the sweep would later delete it by prefix and table out from under
the live pod.

**Known failure mode (present in the reviewed source):** `SeedFromAPI` returns
on its first `SetDesired` error. The goroutine logs `startup seed:` and
returns, so `Inventory` and `RunSweeper` never run for the life of the process.
That disables timed teardown and generation-triggered reapply even though the
manager's reconciler keeps working. Missing pins are one possible trigger. The
code establishes the failure mode. It does not establish that this caused any
particular incident or that it is happening in current pods.

## 3. `EnsureVRF`, the heart of the sidecar

`Store.SetDesired` calls `EnsureVRF` the first time it sees a VPC, and again on
every datapath-reload reapply. It must be idempotent.

1. `vrf.Add(vpc)`: flock; if the VRF exists, return; else pick the next free
   table id, `FlushTable`, `LinkAdd` VRF, sysctls (non-fatal), `LinkSetUp`.
2. `TableID(vpc)` gives N, then `ensureEgressDatapath(vpc, N)`:
   1. `ensureNodeSourceAddress`: read `BGPRouter`, compute `NodeSIDBase`
      (locator, nodeID), write `node_src_addr_table[0]` (WARN and continue on
      error).
   2. `argumentForTableID(N)` must be in [1..0xFFF].
   3. `ensureEgressVeth`: `LinkAdd` veth `ivsN`/`ivpN` if absent, `SetMaster(ivsN -> VRF)`,
      both UP.
   4. `waitForLinkLocalAddr(ivpN)`: up to 2 s, 50 ms poll.
   5. `RouteReplace` in table N: default via the `ivpN` link-local dev `ivsN`.
   6. `ensureGatewayAddress(vpc, ivsN)` (WARN and continue on error). A nil
      prefix is a no-op. Otherwise derive the address, skip `AddrAdd` if the
      address is present, `AddrAdd` otherwise (accept `EEXIST`), then
      `ensureGatewayVRFRoute` (`RouteReplace` main `/128 dev VRF`).
   7. `vrf_table[(ffff:ffff:ffff, N)] = {table N, VETH}`.
   8. `ifindex_vrf_table[ivpN ifindex] = (ffff:ffff:ffff, N)`.
   9. `LoadPinnedProgram usid_egress_prog`, then `attach.AttachEgress(prog, ivpN)`
      (TC ingress, idempotent).
3. `publishGateway` runs on `SetDesired` only, until it succeeds. It resolves
   the first global-scope IPv6 address on any VRF slave. If none exists yet it
   returns `ErrGatewayAddressNotProvisioned` (debug log, retried on the next
   `SetDesired`). Otherwise it calls `PublishGateway` (next section).

Order-of-operations traps:

1. **`ensureNodeSourceAddress` and `ensureGatewayAddress` are non-fatal.** If
   the node-source SID never registers, `usid_egress` fails open and uncounted
   on every encap attempt (`src_or == 0 -> TC_ACT_UNSPEC`). The forward path is
   silently dead.
2. **The maps do not exist before `galactic-cni` pins them.** Everything after
   the address assignment fails with `no such file or directory` if the sidecar
   beats the CNI at boot. The address and route are already assigned by then, so
   a retry re-enters `ensureGatewayAddress` with an address that has finished
   DAD. That is the precondition for the incident in `troubleshooting.md`. The
   boot sequence was inferred, not captured live.
3. **`AddrAdd` only if absent.** Before galactic#623 this was `AddrReplace`,
   which strips the local route of an address that already completed DAD.
4. Address existence is checked by IP equality. It does not verify prefix
   length, DAD completion or `RTN_LOCAL`. The link-local wait checks presence
   only.
5. A non-fatal setup error can leave the VRF marked installed. Ordinary
   `SetDesired` then does not rerun `EnsureVRF`. Generation reapply can retry
   setup. The 5 s sweeper is not a general health repair loop.
6. A gateway publication failure causes no reconcile error and no timed
   requeue. Another `SetDesired` is required, and reapply does not publish.

## 4. Publishing the gateway return path

This makes a backend's reply routable back to the edge node
(`k8sGatewayPublisher.PublishGateway`).

1. List `BGPRouter`s, take the one whose `targetRef` is this node (zero or more
   than one is an error).
2. `allocateGatewayArgument`: reuse the existing `BGPVRFInstance`'s VRFID or the
   lowest free in [1..0xFFF] for this router.
3. `CreateOrUpdate BGPVRFInstance {vpcHex}-{node}` (shared with a tenant pod of
   the same VPC on this node), RT `ASN:uint32(vpcHex)` import and export.
4. `podEntryPoint`: read `eth0`'s `ParentIndex` (the host-side peer ifindex) and
   MAC. This is read **in the pod** because reading it from the host needs
   `CAP_SYS_ADMIN` (setns). The installer drops all caps and adds only `BPF`,
   `NET_ADMIN`, `NET_RAW`.
5. `CreateOrUpdate BGPAdvertisement {vpcHex}-{Base62ToHex(ingress)}-{node}` with
   annotations `ingress-host-ifindex` and `ingress-host-mac`, EVPN L2VPN/EVPN,
   prefix `{gateway}/128`, community RT, VRFID, function End.DT46.
6. `galactic-router` on the edge computes `SID = ComputeSID(edge locator, edge
   nodeID, VRFID, DT46)` and sends EVPN Type-5 `{gateway}/128` with that
   Prefix-SID and the RT to the route reflector.
7. The reflector reflects it to each compute router. `processEVPNPath` skips a
   path whose next-hop is its own address, matches the table by RT to the host
   tenant VRF table T, and calls `RouteEgressAdd({gateway}/128, gw = edge SID,
   table T)`. That resolves link and dmac/smac in the **host** netns.

The advertisement is written only after the entry point (ifindex, MAC)
resolved, so an advertisement never exists without the two facts the host side
needs. A resolve or publish failure logs at WARN and retries on the next
`SetDesired` (`vrfState.gatewayPublished` is set only on success). It never
blocks the forward-path route.

`galactic-router` on the edge is blind to the pod-netns VRF.
`errVRFNotInThisNetns` is treated as an ordinary skip. The sidecar owns its own
egress routes and the router only originates the `/128`.

## 5. The datapath is reloaded under the sidecar

`galactic-cni` reloads the eBPF datapath independently (image roll, schema
change, self-heal). The sidecar has no notification channel. It polls in
`Sweep` (`checkDatapathLocked`, `reapplyLocked`, `datapathGeneration`).

1. The CNI loads the new `usid_egress`, re-pinned on every load. On a schema
   change it recreates every map empty.
2. `ivpN` can still reference the old program and maps. New pins start without
   the old entries.
3. Every 5 s the sweeper reads the generation string
   `"{usid_egress_prog id}/{egress_route_table map id}"`:
   - read error (datapath not loaded): debug log, do nothing;
   - equal to stored and no `reapplyPending`: nothing;
   - first read with nothing installed: record, no reapply;
   - changed: `metrics.Reapplies++`, call `EnsureVRF` again for each installed
     VRF with a live route (not in grace), `EnsureRoute` for each installed
     desired route, then `reapplyPending = !allSucceeded` (retry next sweep).

Consequences:

- Added by #609 and #610. It runs only inside `Sweep`, so if the startup
  goroutine died it never runs.
- Reapply calls `EnsureVRF` again on a live VRF. Before #623 that replaced the
  gateway address and silently broke it.
- Generation detects a program or `egress_route_table` swap. It does **not**
  detect a change to `vrf_table`, `ifindex_vrf_table` or `node_src_addr_table`
  alone, nor stale pre-resolved L2 in existing route values.

## 6. Steady-state reconcile and teardown

`Store` keys routes per EndpointSlice (`namespace/name`) and VRFs per VPC,
rolled up from routes.

| Event | Effect |
|-------|--------|
| `SetDesired(key, route)` | VRF ensured immediately if not installed, gateway publish attempted, route installed, `absentSince` cleared. No delay going up. |
| `SetDesired(key, nil)` (slice deleted or unselected) | Sets `absentSince = now` on the route only. Nothing removed yet. |
| `Sweep`, route past `grace` (30 s) | Skip removal if another slice claims the same (vpc, prefix) (`prefixClaimedElsewhereLocked`). Otherwise `RemoveRoute` (main redirect route, then `RouteEgressDel`). Failure keeps the VPC alive and retries. |
| `Sweep`, VPC with no live route and past `grace` | `withdrawGateway` (delete the `BGPAdvertisement`, best effort), then `RemoveVRF` (delete veth pair, which detaches `usid_egress`; unregister `ifindex_vrf_table` and `vrf_table`; delete VRF). |
| Process exit | No proactive teardown. Kernel state is left for the next instance. |

The two timers never overlap. A VPC's clock starts only when no route
referencing it remains, installed or in grace.

Metrics (`galactic_ingress_sidecar_*`, port 9182): `vrf_active`, `route_active`,
`vrf_teardown_pending`, `route_teardown_pending`,
`reconcile_errors_total{kind=ensure_vrf|ensure_route|remove_vrf|remove_route|reapply_vrf|reapply_route}`,
`reconcile_duration_seconds`, `reapply_total`.

## 7. Repair coverage

Repair is not a universal readiness guarantee.

| Condition | Current behavior |
|-----------|------------------|
| Initial uncached seed fails | Startup goroutine returns; inventory and sweeper never run for that process; the manager continues |
| Inventory fails after a successful seed | Error logged; sweeper still starts |
| Program or egress-map id changes | Running sweeper detects the generation change and reapplies live installed VRFs and routes |
| One map entry lost without a generation change | No entry-by-entry repair from generation polling |
| Gateway publication fails | Logged, retried only on a later `SetDesired`; no publication in reapply |
| Gateway or source provisioning fails non-fatally | VRF can still become installed; route updates need not rerun provisioning |
| Address exists but lost its local route | Address-presence check skips `AddrAdd`; no explicit `RTN_LOCAL` repair |
| Host return endpoint is stale | Return loop keeps retrying a valid-looking advertisement; pruning does not delete advertisement, neighbor or map ownership |
| Process exits | No proactive teardown |

`galactic-vrf` configures metrics but disables the manager health-probe
listener (`HealthProbeBindAddress: "0"`). Metrics reachability, container
Running state and a successful RBAC pre-flight are not end-to-end readiness.

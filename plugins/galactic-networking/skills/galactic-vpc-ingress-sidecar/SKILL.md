---
name: galactic-vpc-ingress-sidecar
description: Covers how Envoy reaches IPv6 VPC backends over Galactic's SRv6 datapath through the galactic-vrf ingress sidecar, in both directions. Use when debugging an Envoy 503 or UF toward a VPC pod, changing galactic-vrf, usid_egress, usid_ingress or the host return path, reading drop_reasons counters, or tracing how EndpointSlices, BGPAdvertisements and EVPN routes become eBPF map rows.
---

# Galactic VPC Ingress Sidecar

How an Envoy pod on an edge node sends a request to a tenant VPC backend over
SRv6 uSID tunnels, and how the reply gets back into the right socket. This
skill is distilled from a source-validated reference. The review covered
Galactic `7bc1c40`, network-services-operator `9697bb8` and infra `a95318f`.
Behavior can drift after those revisions, so check the source at the revision
you run before acting on a detail that matters.

## When to use

- Envoy returns 503 `UF` (often at about 10 s) for a backend in a tenant VPC.
- You are changing `cmd/galactic-vrf`, `internal/ingresssidecar`,
  `internal/installer/sidecarreturn.go`, `usid.c`, or the NSO extension server's
  upstream bind.
- You need to read `drop_reasons`, `vrf_table`, `egress_route_table` or other
  pinned maps and decide what a number means.
- You need to explain why a VPC backend is reachable from one edge and not
  another.

Do not use it for the other ingress type (`galactic-gateway`, XDP NAT+LB) or
for the NAT66 egress shard path. Those share `usid_egress` but are separate.

## The model in one screen

```
Envoy (socket bound to VRF G<vpc9>V)         pod netns, edge node
  -> VRF table N: default via ivpN link-local dev ivsN
  -> ivpN TC ingress: usid_egress looks up (N, backend/128) in egress_route_table
  -> adds a 40 byte outer IPv6 header, dst = backend SID, redirects out eth0
  -> underlay routes the backend's locator to the compute node
compute node: usid_ingress strips the header, FIB lookup in the tenant VRF,
  redirects to the backend's host-side veth or tap
backend replies to the gateway /128 (Envoy's source address in the VPC)
  -> compute usid_egress encapsulates toward the EDGE's advertised return SID
edge node, stage 1 (root netns, eBPF): usid_ingress strips, FIB in return table
  0xF000+VRFID, permanent neighbor, redirect into the pod's eth0
edge node, stage 2 (pod netns, plain kernel): main table "gateway/128 dev VRF"
  makes the VRF driver redo the lookup, RTN_LOCAL delivers to the bound socket
```

Four contracts hold the path together. Preserve all four when you change
anything:

1. **CNI slice to sidecar route.** The CNI publishes a per-pod EndpointSlice
   with the tenant id and SID. The sidecar turns it into a backend `/128` route.
2. **Socket bind to pod VRF.** NSO sets `SO_BINDTODEVICE` to the VRF name the
   sidecar creates.
3. **Gateway advertisement to host return table.** The sidecar publishes a
   `BGPAdvertisement`. The host installer builds the return table from it.
4. **EVPN route to compute return map.** The compute router turns the gateway's
   EVPN Type-5 path into an `egress_route_table` row.

## Five facts that prevent most mistakes

1. **Two namespaces share pinned maps.** The sidecar and Envoy live in the pod
   netns. `galactic-cni`, `galactic-router` and `usid_ingress` live in the host
   netns. Both write the same pinned eBPF maps through the host bpffs, but
   ifindexes, MACs and routes inside map values only mean something in the
   writer's namespace.
2. **One VPC has five numbers.** Base62 VPC string, VRF device name, pod-local
   table id N, advertised VRFID A, and host return table `0xF000 + A`. They are
   not interchangeable. See `identity-and-keys.md`.
3. **`eth0` in the pod is in no VRF.** Only `ivsN` is enslaved. The return path
   therefore needs a main-table `/128 dev VRF` route, and that trick only works
   while the gateway address has an `RTN_LOCAL` route in the VRF table.
4. **Evidence comes in layers.** Desired state, reconciled kernel state,
   classifier counters and application delivery are different things. A green
   layer says nothing about the next.
5. **Do not diagnose from one counter.** `drop_reasons` is per-CPU and contains
   event counters plus one recorded value. Read deltas around a single request.

## Reference files

| Need | File |
|------|------|
| Actors, namespaces, naming, the five numbers, SID layout, synthetic Block | `identity-and-keys.md` |
| Every eBPF map and program, `usid_ingress` steps, kernel objects the sidecar makes | `ebpf-and-kernel-objects.md` |
| Sequences: CNI ADD, sidecar startup, `EnsureVRF`, gateway publish, datapath reload, teardown | `control-plane.md` |
| Forward path, return path (two stages), endpoint discovery, cross-region, shared-map limits | `datapath.md` |
| Sidecar settings, Envoy patch, intervals, source ledger | `deployment-and-source.md` |
| Triage, the SYN/SYN-ACK split, hop checklist H1 to H13, playbooks, counters, logs, repair ladder | `troubleshooting.md` |

Start with `troubleshooting.md` for a live failure. Start with `datapath.md`
for a design question or a change.

## Developer invariants

- **Gateway address** is Envoy's inner source into the VPC and the backend's
  reply destination. It is not the outer source SID.
- **Backend SID and ingress return SID are distinct.** The sidecar never
  computes a backend SID. It reads it from the slice.
- **Sidecar Argument N and advertised Argument A need not match.** The sidecar's
  `vrf_table` key is `(synthetic Block, N)`. The wire SID carries A under the
  real Block. The host return path keys on A.
- **`usid_egress` is attached to TC ingress** of `ivpN`, because traffic sent
  through `ivsN` enters its veth peer there. The name refers to the direction of
  the VPC, not the hook.
- **Encapsulation is one 40 byte outer IPv6 header**, next-header 4 or 41, no
  SRH, no kernel `seg6` lwtunnel.
- **Pre-resolved L2 lives in the route value.** The writer resolves `dmac`,
  `smac` and `link_ifindex` at registration time in its own namespace. Nothing
  refreshes the sidecar's copy on a timer.
- **Process exit does no teardown.** A live Envoy beside a dying sidecar would
  otherwise blackhole in-flight connections.
- **Check every pin writer and reader before changing a map layout.** Host
  installer, CNI ADD, `galactic-router` and the sidecar all write.
- **Keep incident observations dated and separate from invariants.**

## Safe-change checklist

When you change any part of this system:

1. Trace both directions and both control paths, not only the one you touch.
2. For every ifindex or table value you write, name the namespace that reads it.
3. Keep `EnsureVRF` idempotent. It reruns on a live VRF during datapath reload
   reapply. A non-idempotent step (the `AddrReplace` bug) silently breaks
   traffic after the next reload.
4. Do not add a second sidecar pod per node on the assumption that the synthetic
   Block isolates namespaces. It does not (see `datapath.md`, shared maps).
5. Run the root-gated netns tests for the sidecar before declaring a fix. They
   were inspected but not executed in the source review.
6. Verify with `troubleshooting.md` section "Verify a repair", through every
   ingress edge.

## Related skills

- `platform-knowledge`: where Galactic sits in the wider platform.
- `fluxcd-deployment`: how the sidecar patch reaches the cluster. Never force a
  Flux reconcile to speed up a check.
- `linux-netstack`, `cni-networking`, `bgp-routing`, `gobgp`: deeper protocol
  and host-networking background, when installed.
- `clear-writing`: for any issue or report you write about a finding.

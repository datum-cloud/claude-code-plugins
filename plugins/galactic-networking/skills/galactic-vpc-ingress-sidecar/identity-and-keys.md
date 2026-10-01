# Identity, Key Spaces and Naming

Paths without a repository prefix refer to the `galactic` repo.

## The actors and where each runs

| Component | Namespace | Role in this path |
|-----------|-----------|-------------------|
| Envoy (`datum-downstream-gateway`, an `envoyDaemonSet` on `galactic.datumapis.com/node=edge` workers) | Pod netns | Opens upstream sockets bound to the VPC's VRF device |
| `galactic-vrf` sidecar (`cmd/galactic-vrf`, `internal/ingresssidecar`) | Pod netns (same as Envoy) | Creates VRF, veth pair, gateway address, backend routes, `usid_egress` attachment; publishes the gateway advertisement |
| NSO extension server (`network-services-operator/internal/extensionserver/mutate/vpcpod.go`) | n/a | Writes `SO_BINDTODEVICE` into the Envoy cluster |
| `galactic-cni` installer | Host (root) netns | Owns the host return path: locator/function/vrf maps, return table, route, permanent neighbor (`internal/installer/sidecarreturn.go`) |
| `galactic-router` | Host netns | Turns `BGPAdvertisement` into EVPN Type-5 paths; installs remote paths as egress routes on compute nodes |
| `usid_ingress` eBPF | Host netns, fabric uplinks | Decapsulates uSID packets addressed to this node |
| `usid_egress` eBPF | Host (tenant host-side ifaces) and pod (`ivpN`) | Encapsulates toward the SID in `egress_route_table` |

Envoy runs with a Cilium-managed `eth0` in the reviewed deployments.

Consequences:

1. Anything the sidecar creates (VRF, veths, addresses, routes) is invisible
   from the root namespace, and the reverse.
2. The sidecar mounts the host's `/sys/fs/bpf` (`hostPath`, `type: Directory`),
   so both sides write the same pins. Map contents are namespace-agnostic. The
   values (ifindexes, MACs) are only meaningful in the writer's namespace.
3. `eth0` is in no VRF. Only `ivsN` is enslaved.

## The five numbers for one VPC

| Name | Where it lives | How derived | Example (VPC `12`) |
|------|----------------|-------------|--------------------|
| VPC id (base62 string) | EndpointSlice label and annotation `galactic.datum.net/tenant-id` = `<vpc>-<attachment>`; VRF device name | VPC/VPCAttachment ids in the CNI config | `12` |
| VRF device name | Pod netns and host netns | `intf.GenerateInterfaceNameVRF(vpc)` = `G` + vpc zero-padded to 9 + `V` | `G000000012V` |
| Pod-local table id N | Envoy pod netns only | `vrf.Add`: next free id from 1 upward, per netns | `4` |
| Sidecar Argument | `vrf_table` / `ifindex_vrf_table` rows the sidecar writes | `argumentForTableID(N)` = N, must fit 12 bits | `4` |
| Advertised VRFID A (the wire Argument) | `BGPVRFInstance.spec.vrfID`, encoded in the SID's Argument field | Lowest free value in [1, 0xFFF] per BGPRouter, reused if the `BGPVRFInstance` exists | `26` (a historical example, not a fixed allocation) |
| Return table id | Edge node root netns | `0xF000 + A` (`sidecarReturnTableID`) | `61466` |
| Route target | EVPN extended community on `BGPVRFInstance` import/export | `ASN:uint32(low 32 bits of the VPC's numeric value)`; same on every node for the same VPC | `33438:64` for VPC `12` in the reviewed labs |

The two most commonly confused rows: the sidecar's `vrf_table` key uses the
**pod-local table id as Argument under the synthetic Block**. The wire SID
carries the **advertised VRFID as Argument under the real Block**. The host
return path keys on the advertised one, because that is what arrives on the
wire.

The VPC string `12` is a **base62 identifier**. Its hex form is `40` and its
decimal value is 64. It is not the decimal number 12 for route-target
arithmetic. `Base62ToHex("ingress")` is `f30273f7e4` and is not an ASCII
encoding. Gateway advertisement names look like `40-f30273f7e4-<node>`. The
route target uses the low 32 bits of the VPC value. That derivation alone does
not establish global uniqueness.

Per-node Arguments: the Argument is per node, not VPC-global. Two backends of
the same VPC on different nodes can carry different Arguments. This is why
routes are per pod, not per VPC.

## uSID layout (uFMT 48+16, REPLACE-CSID)

From `internal/plumbing/ebpf/uformat/uformat.go`:

```text
bits   1-48   Block     (48)  locator /48, the node's fabric block
bits  49-64   Node-ID   (16)  BGPRouter.spec.nodeID, valid 0x0001-0xDFFF
bits  65-68   Function   (4)  0xE = End.DT46 (L3), 0xF = End.DT2 (reserved)
bits  69-80   Argument  (12)  selects the VRF (valid 0x001-0xFFF, 0x000 reserved)
bits  81-128  Padding   (48)  zero
```

- `locator_table` key = top 64 bits (Block + Node-ID) of the destination.
- `function_table` key = `Block << 4 | Function`.
- `vrf_table` key = `Block << 12 | Argument`.
- Registration rejects Argument zero. A packet addressed to a recognized local
  SID with Argument zero misses `vrf_table`. The source SID is not the key used
  for decapsulation.

## The synthetic Block

`uformat.BlockIngressSidecar = BlockMax = 0xFFFFFFFFFFFF`, prefix
`ffff:ffff:ffff::/48`. The sidecar registers all its `vrf_table` and
`ifindex_vrf_table` rows under this Block.

- It is a local lookup key. It is never on the wire and no other node
  interprets it.
- It is the **ownership marker**. `egressroutemap.SidecarOwnedTableIDs` lists
  `vrf_table` rows whose Block is `BlockIngressSidecar` and the host's 30 s
  egress-route refresh skips those table ids.

It separates sidecar VRF keys from real-Block host keys. It does not make the
whole map set namespace-safe (see `datapath.md`).

## Object naming

| Object | Name | Namespace | Created by |
|--------|------|-----------|------------|
| VRF | `G<vpc9>V` | Pod netns (sidecar) and host netns (CNI, tenant pods) | `vrf.Add` |
| VRF-slave veth end | `ivs<N>` | Pod netns, enslaved to the VRF | `ensureEgressVeth` |
| Veth peer | `ivp<N>` | Pod netns, not enslaved | `ensureEgressVeth` |
| BGPVRFInstance | `<vpcHex>-<node>` | Kubernetes | `PublishGateway`, or CNI ADD (shared) |
| BGPAdvertisement (gateway) | `<vpcHex>-<Base62ToHex("ingress")>-<node>` | Kubernetes | `PublishGateway` |
| BGPAdvertisement (tenant pod) | `<vpcHex>-<attachmentHex>-<node>` | Kubernetes | CNI ADD |
| EndpointSlice | `<podName>`, in the pod's own namespace | Kubernetes | `galactic-bgp` at CNI ADD |
| Return table | `0xF000 + VRFID` | Host routing table space | `ensureSidecarReturnRoute` |

`ivs`/`ivp` names use only the table id, which is unique per VPC per netns and
fits `IFNAMSIZ` because a 12-bit id is at most four digits.

## Gateway address derivation

The gateway address is derived, not allocated:
`sha256(vpcHex + "|" + nodeName)` truncated into the host bits of
`GALACTIC_VRF_GATEWAY_PREFIX`.

- The prefix must be IPv6, byte-aligned, with host bits (a `/128` cannot be a
  derivation prefix), and disjoint from every tenant subnet and IPAM pool.
- Every replica for the same (vpc, node) derives the same value. An empty or
  shared node identity would make those derivations identical.
- There is no collision allocator and no tenant-pool overlap validator.
- The staging desired value is `fd30:e2e::/32`.

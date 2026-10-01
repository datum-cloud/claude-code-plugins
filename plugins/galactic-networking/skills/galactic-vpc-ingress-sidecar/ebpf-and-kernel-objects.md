# eBPF and Kernel Objects

Maps and programs are defined in `internal/plumbing/ebpf/prog/usid.c`. Slot
numbers and names come from the enum at the reviewed revision. The trace slots
are marked `// TEMPORARY` and can change, so check the revision you run:

```sh
git -C galactic show <tag-or-sha>:internal/plumbing/ebpf/prog/usid.c | grep -n 'DROP_REASON_'
```

## Pinned maps (under `attach.PinDir`, `/sys/fs/bpf/galactic`)

Both the CNI installer (host) and the sidecar (pod, through the bpffs mount)
open the same pins.

| Map | Type | Key | Value | Written by (this path) | Read by |
|-----|------|-----|-------|------------------------|---------|
| `locator_table` | hash, 64 | top 64 bits of dst | generation | host: CNI ADD, `ensureSidecarReturnPath` | `usid_ingress` step 2 |
| `function_table` | hash, 128 | `Block<<4\|Fn` | behavior | host: same | `usid_ingress` step 4 |
| `vrf_table` | hash, 8192 | `Block<<12\|Arg` | `vrf_table_id`, counters, `egress_kind` (legacy, unread), `dropped_packets` | host (real Block); sidecar (synthetic Block) | `usid_ingress` step 6, `usid_egress` |
| `ifindex_vrf_table` | hash, 16384 | ifindex | (block, argument) | host CNI (`H` iface); sidecar (`ivpN` ifindex) | `usid_egress` |
| `ifindex_egress_kind_table` | hash, 16384 | host-side ifindex | `EGRESS_KIND_VETH` or `TAP` | host CNI ADD | `usid_ingress` step 9 |
| `egress_route_table` | LPM trie, 32768 | `{prefixlen, table_id, family, addr[16]}` | `{sid, link_ifindex, dmac, smac}` | `galactic-router` (host tables); sidecar (pod tables) | `usid_egress` |
| `node_src_addr_table` | array, 1 | 0 | 16-byte node SID base (Argument zeroed) | host CNI ADD; sidecar `ensureNodeSourceAddress` | `usid_egress` (completes Argument) |
| `public_uplink_table` | array, 1 | 0 | uplink ifindex and MACs | host CNI ADD | `usid_egress` VIP-sourced replies |
| `drop_reasons` | percpu array | reason enum | u64 | both programs | operators |
| `nptv6_table`, `vip_xlat_table` | hash | vrf key / (block, arg, proto, port, dir) | NPTv6 / VIP rewrite | host | both programs; sidecar provisions no translation rows |

Properties worth knowing:

- `egress_route_table` is the only LPM trie. Key `prefixlen` is
  `40 + prefix bits` (32-bit table id plus 8-bit family), up to 168 for an IPv6
  host route.
- `link_ifindex == 0` is the **local pass-through sentinel**. The entry exists
  only to win LPM over a shorter `::/0` default. `usid_egress` returns
  `TC_ACT_UNSPEC` for it.
- The route value carries **pre-resolved L2**. `usid_egress` cannot call
  `bpf_fib_lookup` per packet from its attach point, because a VRF-enslaved
  device blackholes the lookup (l3mdev isolation). The writer resolves the next
  hop at registration time in its own namespace
  (`egressroutemap.resolveLinkAndL2`) and nothing re-resolves it unless someone
  rewrites the entry.
- On an incompatible pinned map, `attach.Load` calls `unpinIncompatibleMaps`
  for every map in the collection, then reloads. New pins refer to new map
  objects. Old attached programs can keep old objects until reattachment. This
  is a multi-writer recovery event, not an atomic replacement. Do not assume
  every CNI ADD registration is rebuilt.

## Programs

| Program | Attach point | Namespace | Purpose |
|---------|--------------|-----------|---------|
| `usid_ingress` | TC ingress (direct-action) on each fabric uplink (auto-detected or `GALACTIC_CNI_EBPF_INTERFACES`; bond slaves included) | Root | Decapsulate uSID packets addressed to this node, FIB-lookup the inner packet in the resolved VRF table, redirect to the tenant interface |
| `usid_egress` | TC ingress of each tenant host-side interface (`H`, tap) and of each sidecar `ivpN` | Root (tenant) or pod (sidecar) | Apply NPTv6/VIP rewrites, then encapsulate toward the SID in `egress_route_table` and redirect out the pre-resolved link |

Verdict discipline in `usid_ingress`: every fail-open path happens before the
locator match and returns `TC_ACT_UNSPEC` (not `TC_ACT_OK`) so a co-resident
CNI's filters still run. After the locator match every failure is
`TC_ACT_SHOT`, because the program is the packet's only intended handler.

### `usid_ingress` steps and what each drop counter means

| Step | Action | Miss or failure result | `drop_reasons` slot |
|------|--------|------------------------|---------------------|
| 0 | `bpf_skb_pull_data` linearise | UNSPEC | `TRACE_ING_PULL_DATA_FAILED` (34) |
| 1 | Parse Ethernet and IPv6, bounds check, must be IPv6 | UNSPEC | `TRACE_ING_ETH_BOUNDS_FAILED` (35), `..ETHERTYPE_MISMATCH` (36), `..IP6_BOUNDS_FAILED` (37) |
| 2 | `locator_table[dst top 64]` | UNSPEC (not ours) | `TRACE_ING_LOCATOR_MISS` (38) |
| 3-4 | Function nibble, `function_table[(block,fn)]`, must be End.DT46 | SHOT | `UNKNOWN_FUNCTION` (0), `UNSUPPORTED_BEHAVIOR` (11) |
| 5-6 | Argument, `vrf_table[(block,arg)]`, bump `packets`, `bytes`, `last_seen_ns` | SHOT | `UNKNOWN_ARGUMENT` (1) |
| 6b | Outer next-header must be 4 (IPIP) or 41 (IPv6) | SHOT | `UNEXPECTED_NEXTHDR` (10) |
| 7 | Strip outer header (`bpf_skb_adjust_room` DECAP, `FIXED_GSO`), pop VLAN if present | SHOT | `STRIP_FAILED` (4), `MALFORMED_INNER` (2), `UNKNOWN_INNER_VERSION` (3) |
| 8 | `bpf_fib_lookup` with `BPF_FIB_LOOKUP_DIRECT \| BPF_FIB_LOOKUP_TBID`, `tbid = vrf_table_id` | SHOT | `FIB_NO_NEIGH` (7), `FIB_UNREACHABLE` (8), `FIB_FRAG_NEEDED` (9), `FIB_LOOKUP_FAILED` (5), `FIB_NO_IFINDEX` (32) |
| 9 | `ifindex_egress_kind_table[ifindex]`: VETH uses `bpf_redirect_peer`, miss or TAP uses `bpf_redirect` | SHOT | `REDIRECT_FAILED` (6) |

A drop at steps 7 to 9 also bumps that `vrf_table` row's `dropped_packets`.
The difference between matches and drops measures classifier paths that did not
record a drop after the VRF lookup. It does not prove interface transmission,
peer receipt, socket delivery or HTTP success. Redirect-helper acceptance is not
delivery.

### `usid_egress` outcomes

`TRACE_IFINDEX_MISS` (23) means no attachment is registered for that ifindex.
`TRACE_MISS_VRF` (17) and `TRACE_MISS_ROUTE` (18) fail open to the kernel.
`TRACE_PASSTHROUGH_ENTRY` (19), `TRACE_MULTICAST_LL_BAIL` (16),
`TRACE_NDP_BAIL` (39), `EGRESS_ROUTE_ENCAP_FAILED` (12),
`EGRESS_ROUTE_REDIRECT_FAILED` (14), `TRACE_REACHED_REDIRECT` (21),
`TRACE_REDIRECT_OK` (22).

If `node_src_addr_table[0]` is zero, `usid_egress` returns `TC_ACT_UNSPEC` with
no counter. This is the silent forward-path failure.

## Linux objects the sidecar creates (pod netns)

Per VPC, shared by all pods of that VPC this Envoy pod serves:

```text
G<vpc9>V   vrf table N                   # vrf.Add
ivsN       veth, master G<vpc9>V, UP     # inner end; holds the gateway /128
ivpN       veth, no master, UP           # peer; usid_egress attached here
table N:   default via <ivpN link-local> dev ivsN
main:      <gateway /128> dev G<vpc9>V   # ensureGatewayVRFRoute
addr:      <gateway /128> dev ivsN       # ensureGatewayAddress (after DAD => RTN_LOCAL)
```

Per backend pod (the backend's `/128`):

```text
main:      <backend /128> dev G<vpc9>V                 # ensureRedirectRoute
map:       egress_route_table[(N, inet6, backend/128)] = {sid, eth0 ifindex, dmac, smac}
```

Why each exists:

- **Default route via the peer's link-local**, not a bare on-link default. An
  on-link default makes the kernel resolve a neighbor for the packet's final
  destination before it reaches the qdisc. Nothing answers for a destination
  `egress_route_table` is about to rewrite, so the packet never reaches
  `usid_egress`. A gateway route resolves the local veth peer instead. That peer
  and its link-local neighbor resolution must stay functional.
- **`usid_egress` on `ivpN`**, not on the VRF device or `eth0`. A VRF master's
  TC egress hook is not the attach point this implementation uses. `eth0` is
  shared by every VPC and `ifindex_vrf_table` holds one (block, argument) per
  ifindex, so it could resolve at most one VPC.
- **Main-table `/128 dev VRF` for each backend.** Neither Envoy nor the cluster
  CNI knows the backend belongs to a VRF, so an unbound socket's lookup would
  resolve the backend out `eth0`. A `/128` wins longest-prefix over the default.
- **Main-table `/128 dev VRF` for the gateway address.** Replies arrive on
  `eth0`, which is in no VRF, so input lookup runs in the main table. The
  address is local only inside the VRF's table. Routing it at the VRF device
  makes the VRF driver redirect the lookup into its own table.

## Reserved return-table range

`0xF000 .. 0xF000 + 0xFFF` (61440 to 65535). Valid Arguments are 1 to 4095, so
normal return tables are 61441 to 65535. This is an operational reservation,
not an allocator guarantee: `vrf.Add` searches free VRF table ids upward
without excluding it. The installer prunes IPv6 routes in this range that are
not in the live set. It preserves routes outside the range, routes without
`Dst`, and destinations matching the live address for that table. It does not
garbage-collect neighbors, VRF-map rows or advertisements.

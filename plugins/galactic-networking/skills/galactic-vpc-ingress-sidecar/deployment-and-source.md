# Deployment, Configuration and Source Ledger

## Sidecar settings

| Environment | Flag | Default | Meaning |
|-------------|------|---------|---------|
| `GALACTIC_VRF_METRICS_PORT` | `--metrics-port` | 9182 | Metrics listener |
| `GALACTIC_VRF_TEARDOWN_GRACE_PERIOD` | `--teardown-grace-period` | 30s | Independent route and then VRF grace periods |
| `GALACTIC_VRF_SWEEP_INTERVAL` | `--sweep-interval` | 5s | Teardown and generation checks |
| `GALACTIC_VRF_NODE_NAME`, fallback `NODE_NAME` | `--node-name` | unset | Enables node-source resolver and gateway publisher |
| `GALACTIC_VRF_NAMESPACE` | `--namespace` | `galactic-system` | BGP object namespace. Does not restrict tenant slices to that namespace |
| `GALACTIC_VRF_GATEWAY_PREFIX` | `--gateway-prefix` | unset | Deterministic gateway address prefix |

Durations must be positive and the sweep cannot exceed the grace. Prefixes must
be IPv6 and byte-aligned, with host bits (`/128` is not usable). With no prefix,
address provisioning is disabled. An independently existing global address could
still be resolved, so do not assert that every unset-prefix configuration
prevents publishing.

## EnvoyProxy patch and security context

Infra injects the sidecar through
`EnvoyProxy.spec.provider.kubernetes.envoyDaemonSet.patch`. Envoy Gateway
reconciles the resulting DaemonSet. The patch is the desired input, not a
Flux-managed Pod template.

The component supplies:

- `galactic-vrf:v0.1.0` with `IfNotPresent` in the base. Staging overrides to
  `v0.0.0-main` with `Always`. Read the running image from
  `status.containerStatuses[].imageID`. A mutable tag is not enough.
- UID 0, capabilities dropped then `NET_ADMIN` and `BPF` added,
  `allowPrivilegeEscalation: false`, read-only root filesystem. Requests 5m CPU
  and 32Mi memory, limit 64Mi memory.
- Host `/sys/fs/bpf` as a `Directory` hostPath (this does not verify a bpffs
  mount), an emptyDir for `/var/lib/cni/galactic-vrf`, and a projected API
  token, CA and namespace volume.
- `NODE_NAME` from the Pod's node name and the configured gateway prefix.
- A privileged `busybox:1.36` init container that sets IPv4 all and default
  reverse-path filtering to zero and enables forwarding and proxy ARP plus IPv6
  forwarding and proxy NDP. It is appended to existing init containers.
- RBAC bound to the service-account group in `datum-downstream-gateway`:
  EndpointSlice and BGP reads, `BGPVRFInstance` create, update and patch, and
  `BGPAdvertisement` lifecycle operations. This is broader than one named
  service account.

The source-address resolver reads the node's **BGPRouter locator and Node-ID**.
A manifest comment that mentions BGPPeer as the source is not the
implementation.

Both `edge-staging` and `edge-compute` include the VPC-ingress component, so it
is not staging-only. Staging also selects Envoy contrib `v1.39.1`. Do not assume
what release tags contain a fix in every environment.

Changing a running tag's registry target does not restart a container.
`imagePullPolicy: Always` applies when a container starts. A controller-driven
rollout from a template change or a replacement Pod can update the sidecar.
Manual Pod deletion is not the only rollout mechanism.

## Host reconciliation intervals

| Loop | Interval | Scope |
|------|----------|-------|
| Sidecar return paths | 30s | Advertisements to return routes, neighbors, maps |
| Egress route refresh | 30s | Host-owned map link and L2. Skips sidecar tables |
| BPF health | 10s | Attachment health and nudges |
| Installer GC | 5min | Host-owned garbage collection. Repairs missing `vrf_table` rows from live BGPVRFInstances and kernel VRFs |
| Credential refresh | 300s | Installer API credentials |
| Sidecar sweeper | 5s | Teardown and generation checks |

Intervals do not bound convergence when prerequisites fail, a goroutine exits,
the API is unavailable, or errors need a later event.

## Source ledger

Paths are in `datum-cloud/galactic` unless prefixed. Reviewed revisions:
Galactic `7bc1c4019c1e111b9d3b77410d55c73c3766fa14`, NSO
`9697bb8af010f484aa1737d9f1c8eb1c54a141e0`, infra
`a95318fe19986c571eebdee100fd3c7146a2f878`. Read the local checkouts under the
`datum-cloud/` workspace rather than fetching from GitHub, and check their
revision against these first.

| Concern | Implementation |
|---------|----------------|
| Sidecar startup, seed goroutine, health setting, RBAC pre-flight | `cmd/galactic-vrf` |
| Desired route parsing, store, grace, generation reapply, kernel setup, publisher | `internal/ingresssidecar` |
| Gateway address fix and root-gated regression test | `internal/ingresssidecar/gatewayaddress.go`, `gatewayaddress_netns_test.go` |
| Sidecar configuration | `internal/config/vrf.go`, `internal/config/config.go` |
| CNI BGP and EndpointSlice publication | `internal/cnibgp` |
| Tap and runtime handoff | `internal/cnitap` |
| Names and base62 conversion | `internal/crdnames/crdnames.go` |
| Host return-path reader and ticker loops | `internal/installer/sidecarreturn.go`, `internal/installer/installer.go` |
| Map definitions, encap, decap, FIB, redirects, trace enum | `internal/plumbing/ebpf/prog/usid.c` |
| uSID fields and synthetic Block | `internal/plumbing/ebpf/uformat/uformat.go` |
| Egress route serialization, SID and L2 validation, ownership marker | `internal/plumbing/ebpf/egressroutemap` |
| Pin recovery, TC attach, uplink detect, cache, watch | `internal/plumbing/ebpf/attach` |
| Namespace-local VRF allocator | `internal/plumbing/vrf/vrf.go` |
| Egress API and SID derivation | `internal/plumbing/srv6` |
| EVPN best-path import and withdrawal | `internal/runtime/gobgp/monitor.go` |
| Host GC | `internal/gc/gc.go` |
| Envoy upstream bind mutation | NSO `internal/extensionserver/mutate/vpcpod.go` |
| VPC address and backend index | NSO `internal/extensionserver/cache/index.go` |
| Direct VPC backend branch | NSO `internal/controller/gateway_controller.go` |
| Cross-cell EndpointSlice writeback | NSO `internal/controller/vpcendpointslice_writeback.go` |
| Sidecar deployment component | infra `apps/network-services-operator/downstream/components/vpc-ingress/vpc-vrf-sidecar.yaml` |
| Staging overrides | infra `apps/network-services-operator/downstream/edge-staging/kustomization.yaml` |
| Compute edge inclusion | infra `apps/network-services-operator/downstream/edge-compute/kustomization.yaml` |
| Federation policy | infra `apps/network-services-operator/downstream/federated/clusterpropagationpolicy.yaml` |
| Central and east cluster configuration | infra `clusters/edge/us-central-1-staging-lab/kustomization.yaml`, `clusters/edge/us-east-1-staging-lab/kustomization.yaml` |

The root-gated datapath and netns tests were inspected, not executed, in the
source review.

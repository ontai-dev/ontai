# ONT Git Tracking
## Repository Status
| Repository   | Branch                  | Last Commit | Status                    |
|---|---|---|---|
| ontai        | session/1-governor-init | e1d06cf     | active                    |
| conductor    | session/1-governor-init | 5e5bebb     | active                    |
| guardian     | session/1-governor-init | d3b5e74     | active                    |
| platform     | session/1-governor-init | 5dbe1aa     | active                    |
| wrapper      | session/1-governor-init | 3438aec     | active                    |
| seam-core    | session/1-governor-init | 54d4409     | active                    |

## Branch Convention
session/{N}-{role}-{description} for all work branches.
main is never committed to directly.
No pushes to remote until Platform Governor authorizes.

## Commit Log
| Repository   | Hash    | Message                                                                        |
|---|---|---|
| conductor   | d176ed9 | session/1: skeleton structure — directories, go.mod, design docs               |
| guardian | 194934c | session/1: skeleton structure — directories, go.mod, design docs               |
| platform | a38188f | session/1: skeleton structure — directories, go.mod, design docs               |
| wrapper    | 86807d4 | session/1: skeleton structure — directories, go.mod, design docs               |
| ontai        | d476d02 | session/1: tracking files updated with final commit hashes                     |
| ontai        | d54ac90 | session/1: GIT_TRACKING.md final hash correction                               |
| conductor   | 56e1582 | session/2: pkg/runnerlib — shared library types, constants, generators, builder, unit tests |
| guardian | c205ea5 | session/3: RBACPolicy CRD types, validation logic, reconciler, manager skeleton, unit and integration tests |
| ontai        | 5abfded | session/3: tracking files updated with exit state and guardian commit hash |
| guardian | 64ac2e8 | session/4: remaining CRD types, RBACProfileReconciler (CS-INV-005), IdentityBinding stub, EPGReconciler stub, PermissionSnapshot types, unit and integration tests |
| ontai        | e1db7b9 | session/4: tracking files updated with exit state and guardian commit hash |
| guardian | 38056c9 | session/5: EPG computation with ceiling intersection, PermissionSnapshot generation, EPGReconciler, unit and integration tests |
| ontai        | d92ff78 | session/5: tracking files updated with exit state and guardian commit hash |
| guardian | 230e48c | session/6: delivery loop — reconcileDrift, PermissionSnapshotReceipt watch, drift dispatch, unit and integration tests |
| guardian | 8324c0b | session/7: admission webhook — decision.go, rbac_handler.go, server.go, webhook config, main.go wiring, 13 unit + 7 integration tests |
| conductor   | bcbb224 | session/governor: fix pack-compile misclassification across runnerlib, schema, progress, backlog |
| ontai        | 0fc60fb | session/governor: fix pack-compile misclassification across runnerlib, schema, progress, backlog |
| ontai        | 1f1071d | session/governor: rebranding to Seam — operator names, consolidated platform CRDs, IdentityProvider schema, branding directory, tracking updates |
| seam-core    | c6d4626 | seam-core: repository initialization — schema controller skeleton                               |
| conductor    | 4e09ead | session/governor: Seam rename — module paths, Go imports, licensing removal, design doc rename  |
| guardian     | 0eb92da | session/governor: Seam rename — module to guardian, import paths, annotation value, design doc  |
| platform     | 001fb16 | session/governor: Seam rename — module to platform, design doc rename, licensing removal        |
| wrapper      | 0371234 | session/governor: Seam rename — module to wrapper, design doc rename                            |
| ontai        | dd7247f | session/governor: Seam rename — schema renames, .gitignore, tracking updates, seam-core init    |
| guardian     | 52e1bb6 | session/8: bootstrap RBAC window — INV-020, CS-INV-004                                          |
| guardian     | e7a401b | session/schema: guardian — wire controller-gen, replace handwritten CRD YAML and deepcopy       |
| guardian     | 5fe5952 | session/10: Verb enum fix (F-S3C) and IdentityProvider reconciler                               |
| seam-core    | d0fba81 | session/schema: lineage stub — InfrastructureLineageIndex types and pkg/lineage shared library  |
| guardian     | d1e35b7 | session/11: WS1+WS2 — IdentityBinding trust methods and PermissionSet reconciler               |
| guardian     | 740be82 | session/11: WS3 — PermissionService gRPC server (four operations)                              |
| conductor    | 05b63e6 | session/12: WS1–WS3 — binary entry points, capability engine, execute/agent modes              |
| conductor    | 1ae4bf9 | session/13: WS1+WS2 — ConfigMap write, agent control loops                                    |
| conductor    | 12f7019 | session/14: all 17 capability handlers — real implementations with client interfaces           |
| conductor    | c39a8c3 | session/15: WS1 adapters, WS2 Ed25519 signing, WS3 SealedCausalChain webhook                  |
| conductor    | 0ccbb2a | session/16: WS1 signing loops + WS2 local PermissionService gRPC                              |
| conductor    | 5e5bebb | session/18: PermissionSnapshot pull loop — target cluster pulls, verifies INV-026, updates store |
| platform     | 8c02a4f | session/19: WS1+WS2 — TalosCluster CRD types, reconciler scaffold, CAPI helpers, main.go       |
| platform     | 5dbe1aa | session/20: WS1+WS2 — SeamInfrastructureCluster/Machine CRDs, SIC+SIM reconcilers, unit tests  |
| wrapper      | 3438aec | session/21: WS1+WS2+WS3 — ClusterPack/PackExecution/PackInstance CRDs, reconcilers, 17 unit tests |
| seam-core    | be0aaa1 | session/22: LineageController — ILI spec, controller-gen, manager, LineageReconciler (9 GVKs), governance annotation, LineageSynced transfer, 9 tests |
| guardian     | d3b5e74 | session/24: WS1 — SealedCausalChain immutability webhook (5 kinds, /validate-lineage), 16 unit tests green |
| seam-core    | 54d4409 | session/24: WS2+WS3 — ILI rootBinding immutability + controller-authorship gate, 29 unit tests green |

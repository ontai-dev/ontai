# ONT Git Tracking
## Repository Status
| Repository   | Branch                  | Last Commit | Status                    |
|---|---|---|---|
| ontai        | main                                        | (pending)   | active (tracking)         |
| conductor    | session/15-capability-tests                 | (pending)   | drift detection + circuit breaker complete, pre-PR |
| guardian     | main                                        | 112f99e     | PR #18 merged             |
| platform     | main                                        | (pending)   | EnsureRemoteConductorRBAC widened, pre-PR |
| wrapper      | main                                        | a1b0743     | PR #15 merged             |
| seam-core    | main                                        | 3f5a0b4     | Dockerfile fix committed      |
| domain-core  | main                                        | f01ca65     | active                    |

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
| conductor    | 2e2afa9 | session/25: CapabilityRBACProvision — Ed25519 signature verification (INV-026) + bootstrap window mode (INV-020), 4 new unit tests green |
| platform     | 8c02a4f | session/19: WS1+WS2 — TalosCluster CRD types, reconciler scaffold, CAPI helpers, main.go       |
| platform     | 5dbe1aa | session/20: WS1+WS2 — SeamInfrastructureCluster/Machine CRDs, SIC+SIM reconcilers, unit tests  |
| wrapper      | 3438aec | session/21: WS1+WS2+WS3 — ClusterPack/PackExecution/PackInstance CRDs, reconcilers, 17 unit tests |
| seam-core    | be0aaa1 | session/22: LineageController — ILI spec, controller-gen, manager, LineageReconciler (9 GVKs), governance annotation, LineageSynced transfer, 9 tests |
| guardian     | d3b5e74 | session/24: WS1 — SealedCausalChain immutability webhook (5 kinds, /validate-lineage), 16 unit tests green |
| seam-core    | 54d4409 | session/24: WS2+WS3 — ILI rootBinding immutability + controller-authorship gate, 29 unit tests green |
| platform     | 82533c8 | session/36 WS1: ConductorReady condition — EnsureConductorDeploymentOnTargetCluster returns (bool,error), ensureConductorReadyAndTransition, RemoteConductorAvailableFn, 3 new tests; Gap 27 WS1 |
| wrapper      | bbb3361 | session/36 WS2: PackExecutionReconciler gate 0 ConductorReady — isConductorReadyForCluster, ConditionTypePackExecutionWaiting, 3 new gate 0 tests, 20 tests green; Gap 27 WS2 |
| seam-core    | 7f24eed | session/37 WS1: pkg/conditions — platform-wide condition vocabulary package; all 5 operator condition/reason constants; ValidateCondition/KnownConditionTypes/ValidReasonsFor; 3 test suites green |
| seam-core    | fcec232 | session/37 WS2: api/v1alpha1 ILI types — re-export ConditionTypeLineageSynced/ReasonLineageControllerAbsent from pkg/conditions; SC-INV-002 closed for seam-core |
| guardian     | 8155ba2 | session/37 WS2: lineage_conditions.go — re-export ConditionTypeLineageSynced/ReasonLineageControllerAbsent from seam-core/pkg/conditions; SC-INV-002 closed for guardian |
| conductor    | d23a6fc | session/38 WS1: SigningLoop stores signed PackInstance artifacts as Secrets; seam-pack-signed-{clusterName}-{packInstanceName}; idempotent; 3 new tests; 9 suites green |
| conductor    | f7a127e | session/38 WS2: PackInstancePullLoop — tenant cluster pulls Secrets, verifies Ed25519, creates PackReceipt; bootstrap window; idempotent; 9 unit tests; Gap 28 resolved |
| domain-core  | f01ca65 | session/39 WS1: Layer 0 scaffold — DomainLineageIndex, 8 abstract business primitives, pkg/lineage, README; core.ontai.dev; no controllers |
| platform     | 871db38 | session/39 WS2: Gap 31 — lineage_conditions.go in platform/api/v1alpha1 and platform/api/infrastructure/v1alpha1 re-export from seam-core/pkg/conditions; SC-INV-002 closed |
| wrapper      | bacd59d | session/39 WS2: Gap 31 — lineage_conditions.go re-exports from seam-core/pkg/conditions; SC-INV-002 closed |
| seam-core    | 2370dbe | session/40 WS1: pkg/e2e — ClusterClient, ConditionPoller, CRApplier, NamespaceEnsurer, RegistryClient (OCI Distribution Spec, pure net/http); compiles clean |
| seam-core    | 5285c9e | session/40 WS2: e2e suite bootstrap — Ginkgo/Gomega, MGMT_KUBECONFIG/TENANT_KUBECONFIG/REGISTRY_ADDR env vars, skip-all gate, make e2e target |
| guardian     | ec9c701 | session/40 WS2: e2e suite bootstrap — Ginkgo suite, env vars, skip-all when MGMT_KUBECONFIG absent, make e2e target |
| platform     | 60b0095 | session/40 WS2: e2e suite bootstrap — Ginkgo suite, env vars, skip-all when MGMT_KUBECONFIG absent, make e2e target |
| wrapper      | de2a9a1 | session/40 WS2: e2e suite bootstrap — Ginkgo suite, env vars, skip-all when MGMT_KUBECONFIG absent, make e2e target |
| conductor    | 19dcc03 | session/40 WS2: e2e suite bootstrap — Ginkgo suite, env vars, skip-all when MGMT_KUBECONFIG absent, make e2e target |
| guardian     | 34437c0 | session/40 WS4: e2e stubs — webhook_test, rbacprofile_test, identityprovider_test (10 It blocks, all skip); each with pre-condition comment block |
| platform     | 2264170 | session/40 WS4: e2e stubs — taloscluster_bootstrap_test, conductorready_test, port50000_test (12 It blocks, all skip); each with pre-condition comment block |
| wrapper      | 9cf394c | session/40 WS4: e2e stubs — packexecution_test, packinstance_drift_test (10 It blocks, all skip); each with pre-condition comment block |
| conductor    | 4fbbffd | session/40 WS4: e2e stubs — signing_loop_test, packinstance_pull_loop_test, snapshot_pull_loop_test (15 It blocks, all skip); each with pre-condition comment block |
| seam-core    | bbcc042 | session/40 WS4: e2e stubs — lineage_controller_test, lineage_synced_test (9 It blocks, all skip); each with pre-condition comment block; all 4 suites green |
| ontai root   | 9fcb543 | session/4: CLAUDE.md Section 16 -- Context Compaction Safety Protocol (Governor directive) |
| ontai root   | 153f31a | session/4: CLAUDE.md Section 17 -- e2e CI Contract and Skip-Reason Standard (Governor directive) |
| guardian     | 16c85f4 | session/4: G-BL-CR-IMMUTABILITY -- operator-authorship guard (operator_cr_guard.go, handler, server wiring, webhook config, 10 unit tests, 6 e2e stubs) |
| conductor    | a2eada4 | session/4: C-COREDNS-PATCH -- remove INV-001-violating shell script from compiler, phase 05 meta updated, 2 new unit tests, 3 e2e stubs |
| conductor    | a0a4c53 | session/4: C-KUEUE-WEBHOOK -- move webhook scoping to Phase 00 in enable-ccs-mgmt.sh, 1 new unit test, 3 e2e stubs |
| platform     | 7f70533 | session/4: C-34 -- TalosClusterSpec.CAPI changed to *CAPIConfig, CAPIEnabled() helper, deepcopy + controller + test fixes |
| conductor    | f7c66ad | session/4: C-34 -- remove explicit CAPIConfig{Enabled:false} from management cluster builders, regression test |
| seam-core    | 91aacd8 | session/14: gate 5 conditions (WrapperRunnerRBACNotReady), TalosCluster Ready printcolumn, CRD update |
| seam-core    | d6339de | session/14: fix Dockerfile COPY path for seam-core build |
| conductor    | faf8e72 | session/14: T-2B-9 conductor -- delete old-GVK CRD YAMLs, migrate all dynamic GVR constants to infrastructure.ontai.dev, update all test files; gate 5 SAR RBACChecker hook; all unit tests pass |
| wrapper      | 2807054 | session/14: T-2B-9 wrapper -- delete infra.ontai.dev CRD YAMLs, migrate reconcilers/tests to infrastructure.ontai.dev; gate 5 rbacAllowedStub, newJob ownerRef fix; all unit tests pass |
| ontai root   | 67e16c7 | session/14: lab bake patches -- DSNS_SERVICE_IP, dsns LB-IPAM, signing key rotation, wrapper-runner-cluster-scoped ClusterRole; ontai-schema to 9b65995 |
| conductor    | 0d51de3 | compiler: remove namespace emission from import paths (CP-INV-004) -- REVERTED |
| platform     | 2a5e096 | platform: fix import path namespace ordering and document machineconfig model -- REVERTED |
| ontai root   | 770072d | root: add PLATFORM-BL-MACHINECONFIG-IMPORT-CAPTURE, update PROGRESS.md |
| conductor    | 66c875e | compiler: restore seam-tenant namespace manifest for mode=import (Option B) |
| platform     | d2c49db | platform: restore original import reconcile ordering and fix schema doc |
| conductor    | f1148ec | conductor: PublishAllWithRetry, TenantDynamicClient for pack-deploy, packbuild ccs-dev spec |
| platform     | 3d39e92 | platform: ensureWrapperRunnerResources in ensureTenantOnboarding |
| conductor    | 6fe4d5c | conductor: writePackReceipt in executeSplitPath success path |

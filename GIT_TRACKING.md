# ONT Git Tracking
## Repository Status
| Repository   | Branch  | Last Commit | Status                    |
|---|---|---|---|
| ontai        | main    | (pending session close commit) | PROGRESS.md + GIT_TRACKING.md updated session/18 drift guard + pack-deploy fix |
| conductor    | session/17-etcd-s3-credential-injection | 25f9a91 | etcd-backup S3 upload fix |
| conductor    | session/17-pki-rotation-automation | b1cc44c | Kubeconfig method + kubeconfig Secret refresh in pkiRotateHandler |
| conductor    | session/17-hardening-profile-tests | 01a5cb5 | talos-upgrade rolling upgrade + Nodes()/Health() interface + installer image fix |
| conductor    | session/17-hardening-profile-tests | 772e318 | T-23 TalosVersionDriftLoop -- Kubernetes API version check, InfrastructureTalosCluster DriftSignal |
| conductor    | session/17-hardening-profile-tests | 5144841 | hardeningApplyHandler bug fix + unit tests + CODEBASE.md |
| conductor    | session/17-hardening-profile-tests | cd63b00 | session/18: terminating-namespace drift guard + packDeploy alphabetical-first-match fix |
| guardian     | main    | PR #19 merged | T-25a RBACProfile ceiling, unused snapshotReceiptGVR lint fix |
| platform     | session/17-etcd-s3-credential-injection | f03804e | S3 credential injection for etcd backup/restore |
| platform     | session/17-pki-rotation-automation | e6b64ab | PKI rotation automation + cert expiry detection + test fixtures |
| platform     | session/17-hardening-profile-tests | 3a9acd9 | DriftSignalReconciler InfrastructureTalosCluster handler; platform-executor RBAC upgradepolicies fix |
| platform     | session/17-hardening-profile-tests | 967ba3f | DriftSignalReconciler: observedTalosVersion patch, out-of-band TCOR record, TCOR revision bump |
| platform     | session/17-hardening-profile-tests | 2b2bf3b | pkirotation e2e (TENANT-PKI-ROTATE, TENANT-PKI-CLUSTER-REACH) + registry client in day2 suite |
| seam-core    | session/17-pki-rotation-automation | (committed) | pkiRotationThresholdDays + pkiExpiryDate fields |
| wrapper      | main    | PR #16 merged | N-step rollback, DriftSignal cascade delete, errcheck lint fix |
| wrapper      | main    | ee36691 | session/18: fix stale runner.ontai.dev RunnerConfig watch GVK |
| domain-core  | main    | PR #3 merged | DomainLineageIndex schema amendment |

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
| wrapper      | e431629 | wrapper: cascade DriftSignal deletion from handleClusterPackDeletion — step 2.5, unit test added |
| conductor    | f9f73e4 | conductor: orphan teardown when ClusterPack deleted, stale Secret cleanup, artifact parser flat-form fix, 3 new unit tests |
| platform     | 10b94d5 | platform: widen conductor-agent-tenant ClusterRole for orphan teardown (delete verbs on all groups, rbac.authorization.k8s.io) |
| conductor    | c22a4f5 | conductor: Force=true on writePackReceipt SSA to resolve signatureVerified field manager conflict |
| seam-core    | 33e786a | seam-core: rollback schema -- POR Previous* fields, ClusterPackVersion/RBACDigest/WorkloadDigest, RollbackToRevision on ClusterPackSpec |
| conductor    | 9de3e78 | conductor: rollback anchor -- populate POR rollback fields, ontai.dev/cluster-pack label, previous-state embedding, 2 new tests |
| wrapper      | 9e0baae | wrapper: ClusterPackReconciler handleRollback -- patches spec to previous version/digests, clears annotation, 3 unit tests |
| seam-core    | f380fb6 | seam-core: N-step rollback schema -- remove Previous* fields, update §7.8 retention model |
| conductor    | fdfa63d | conductor: N-step rollback -- superseded POR retention replaces predecessor deletion |
| wrapper      | 51039d6 | wrapper: N-step rollback -- handleRollback reads target POR directly, no N-1 guard |
| conductor    | 1e481af | session/15: fix pack-deploy RBAC apply to tenant cluster and helm namespace rendering |
| conductor    | 7563ebe | session/15: tenant role wiring, INV-026 signing key enforcement, raw packbuild split, TenantBootstrapSweep deleted |
| conductor    | 34602eb | conductor: helm hook filtering, slog JSON handler, remove spec dump from POR log |
| guardian     | 693ba7d | session/15: GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING -- tenant snapshot path in RBACProfileReconciler, TenantProfileRunnable clears RBACPolicyRef |
| ontai root   | 52c4d36 | session/15 close: CODEBASE.md across all repos, GAP_TO_FILL cleanup, ccs-dev INV-026 bundle fix, ccs-mgmt signing key rotation |
| conductor    | 25f9a91 | conductor: fix etcd-backup S3 upload for MinIO over HTTP (bytes.NewReader) |
| platform     | f03804e | platform: inject S3 credentials into etcd backup/restore executor Jobs |
| seam-core    | (session/17-pki-rotation-automation) | seam-core: add pkiRotationThresholdDays to spec and pkiExpiryDate to status |
| platform     | 211defb | platform: implement PKI rotation automation with cert expiry detection |
| platform     | e6b64ab | platform: fix S3 secret test fixtures to include required credentials |
| conductor    | b1cc44c | conductor: add Kubeconfig method and kubeconfig Secret refresh to pkiRotateHandler |
| conductor    | a8ad30e | conductor: fix hardeningApplyHandler to read machineConfigPatches as list |
| conductor    | 5144841 | conductor: update CODEBASE.md for hardeningApplyHandler fix and unstructuredList sharp edge |
| platform     | 4fbe1e2 | platform: add hardeningprofile e2e tests for bootstrap and import clusters |
| platform     | 2b2bf3b | platform: add pkirotation e2e tests and registry client to day2 suite |
| conductor    | cd63b00 | conductor: fix three drift/pack-deploy alphabetical-first-match bugs (session/18) |
| wrapper      | ee36691 | wrapper: fix stale runner.ontai.dev RunnerConfig watch GVK (session/18) |

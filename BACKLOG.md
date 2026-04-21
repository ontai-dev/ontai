# ONT Platform: Backlog

**Last updated:** April 21, 2026
**Branch:** session/13-clusterpack-rbac-split WS1-WS8 complete

Priority: High / Medium / Low

---

## Critical (Blocks Alpha Release)

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. Phase B script ready. Prerequisite: ccs-dev VMs and TalosCluster CR for ccs-dev (configs/ccs-dev/compiled/bootstrap/ does not exist yet -- need compiler bootstrap run for ccs-dev). |
| LAB-ENABLE-BUNDLE-SEAM-CORE-CRDS | lab, seam-core | SC-INV-003 violation found in phase A: SeamMembership CRD was absent from enable bundle. Fixed in session/13 (seam-core-crds.yaml added to 00-infrastructure-dependencies). Validate fix survives next full cluster-up. CLOSED 2026-04-21 (session/13). |
| LAB-CONDUCTOR-CLUSTER-REF | lab, conductor | Conductor enable bundle missing --cluster-ref=ccs-mgmt arg. Fixed in session/13 (conductor-deployment.yaml updated). Compiler enable must pass --cluster-name flag. CLOSED 2026-04-21 (session/13). |

---

## High Priority

| ID | Component | Description |
|----|-----------|-------------|
| SEAM-CORE-BL-DECLARING-PRINCIPAL | seam-core, guardian, platform, wrapper | CLOSED 2026-04-21 (session/12). declaringPrincipal on rootBinding, createdAt+actorRef on descendantRegistry, outcomeRegistry with OutcomeReconciler, lineageIndexRef in guardian audit. ontai-schema PR #1. 13 new unit tests. |
| PLATFORM-BL-TENANT-GC | platform | CLOSED 2026-04-21 (session/11). Finalizer platform.ontai.dev/tenant-namespace-cleanup added to CAPI-enabled TalosCluster. Deletes seam-tenant-{name} on deletion. 4 unit tests. platform f7a310c. |
| G-BL-CR-IMMUTABILITY | guardian | CLOSED 2026-04-20 (session/4). operator-authorship guard implemented; 10 unit tests + 6 e2e stubs. guardian commit 16c85f4. |
| G-BL-CNPG-POOLER-AUTH | guardian | CLOSED 2026-04-21 (session/13). RunWithRetry now takes configFn closure; credentials re-read from secret on every retry. EPG stale-on-restart also fixed (permissionSnapshotStaleFilter.Create handles Fresh=False snapshots). guardian 044689b. |
| C-COREDNS-PATCH | compiler | CLOSED 2026-04-20 (session/4). INV-001-violating shell script removed from compiler; phase 05 meta updated; CI script step 7a handles patch inline. conductor commit a2eada4. 3 e2e stubs. |
| C-KUEUE-WEBHOOK | compiler | CLOSED 2026-04-20 (session/4). Webhook scoping moved to Phase 00 immediately after kueue-controller.yaml; wait_crd guard added. conductor commit a0a4c53. 3 e2e stubs. |

---

## Medium Priority

| ID | Component | Description |
|----|-----------|-------------|
| WRAPPER-BL-ILI-DECLARING-PRINCIPAL | guardian, wrapper | PARTIALLY CLOSED 2026-04-21 (session/13-clusterpack-apply-fixes WS5 on separate branch). MutatingWebhookConfiguration added to compiler enable bundle. Needs cluster apply and verification. Session/13-clusterpack-rbac-split does NOT include this fix (separate branch). |
| WRAPPER-BL-CROSS-CLUSTER-APPLY | conductor, wrapper | PARTIALLY CLOSED 2026-04-21 (session/13-clusterpack-rbac-split WS3-WS7). Three root causes fixed: (1) kernel HaltOnFailure returns error (session/13-clusterpack-apply-fixes WS2); (2) wrapper reconciler parses OperationResult JSON (session/13-clusterpack-apply-fixes WS3); (3) pack-deploy routes RBAC through guardian intake, pre-creates namespaces (session/13-clusterpack-rbac-split WS6). Awaiting cluster apply and nginx retest (WS9-WS10). |
| WRAPPER-BL-GUARDIAN-RBACPROFILE-PROVISIONED | guardian, conductor | WaitForRBACProfileProvisioned interface method has no production implementation. The stub always returns nil immediately. A real implementation needs management cluster dynamic client to poll tenant-{clusterRef}/rbacprofile/{componentName} for provisioned=true. Implement as part of cluster verification session. |
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | PackInstance deletion must trigger ClusterPack reconcile with PackExecution cascade delete. Fixed in 51fd2ec. Verify no regression after ARCH-BL-RUNNERCONFIG-UNIFICATION. |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | platform | TalosClusterReconciler status patch conflicts under 2-replica deployment. Use RetryOnConflict. |
| PLATFORM-BL-3-LOCALQUEUE | platform | Platform must create LocalQueue in seam-tenant for tenant clusters. Currently only management cluster gets it from compiler phase 05. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | Wrapper ConductorReady gate should watch RunnerConfig status and trigger immediately when capabilities appear rather than polling on 30s requeue. |
| G-BL-SNAPSHOT-ALIAS | guardian | snapshot-management should cover ccs-mgmt for management cluster. Eliminates redundant snapshot-ccs-mgmt. |
| G-BL-IDP-POLLING | guardian | IdentityProviderReconciler must poll OIDC provider for group membership changes and record identitybinding.drift_detected. Requires Keycloak or Dex in lab. |
| G-BL-SELF-AUDIT-MISSING | guardian | PARTIALLY CLOSED 2026-04-21 (session/12). rbacprofile.provisioned confirmed in audit trail (AuditWriter wired in WS3/session/11). lineageIndexRef now populated on all governed-object events (WS10). rbac.would_deny still absent -- separate investigation required. |
| GUARDIAN-BL-ENVTEST-FAIL | guardian | CLOSED 2026-04-20 (session/7). Three root causes fixed: RBACPolicy finalizer early-return, EPGReconciler OperatorNamespace unset, OIDC HTTP timeout race. All guardian integration suites green. |
| WRAPPER-BL-ENVTEST-GC | wrapper | TestPackInstance_OwnerRefCascade_DeletedWhenPackExecutionDeleted requires kube-controller-manager GC controller. envtest starts API server and etcd only; GC controller is not started. Test must run against a real cluster. Promote when cluster e2e suite is established (TENANT-CLUSTER-E2E). |
| SEAM-CORE-BL-DESCENDANT-LABELS | guardian | PARTIALLY CLOSED 2026-04-20 (session/10d). Platform RunnerConfig and Wrapper PackInstance wired. Guardian PermissionSnapshot wiring deferred -- no single root RBACPolicy per snapshot; architectural question unresolved. See GUARDIAN-BL-PERMISSIONSNAPSHOT-WIRING. |
| PLATFORM-BL-ILI-CROSS-NS | platform, seam-core | CLOSED 2026-04-20 (session/10d). Added root-ili-namespace label to SetDescendantLabels. DescendantReconciler reads the label and resolves cross-namespace ILI. Unit test added. platform c0d3cab, seam-core ca40489. |
| PLATFORM-BL-HARDENINGPROFILE-MERGE | platform | HardeningProfileRef field absent from TalosClusterSpec. TalosConfigTemplate cannot merge HardeningProfile patches at runtime. Decision 11: schema PR to ontai-schema required before implementation. Governor session needed. |
| GUARDIAN-BL-PERMISSIONSNAPSHOT-WIRING | guardian | CLOSED NOT A GAP (Governor ruling 2026-04-20). PermissionSnapshot lineage wiring deferred by design. |
| CONDUCTOR-BL-CAPABILITY-IMPL | conductor | 14 named capability handlers are minimal stubs. Full implementation required for day2 operations on live cluster. One session per capability family: etcd ops, node ops, PKI, upgrade, pack-deploy. |

---

## Low Priority / Polish

| ID | Component | Description |
|----|-----------|-------------|
| CONDUCTOR-BL-EXECUTION-ORDER | conductor | Staged manifest apply confirmed implemented. Verify with multi-manifest pack test. |
| WRAPPER-BL-PACKINSTANCE-VERSION-DOUBLE-V | wrapper | Ready condition message says vv0.1.2 double v prefix. Fixed in 51fd2ec. Verify. |
| C-34 | compiler | CLOSED 2026-04-20 (session/4). *CAPIConfig pointer change in platform API; CAPIEnabled() helper; nil suppresses capi block entirely. platform commit 7f70533, conductor commit f7c66ad. |
| CONDUCTOR-BL-RESULT-CM-TTL | conductor | OperationResult ConfigMap TTL. Fixed in 6d31b77. Verify GC happening. |

---

## Not Yet Tested

| Area | Component | Description |
|------|-----------|-------------|
| PackReceipt | conductor | Conductor agent on tenant cluster creating PackReceipt. Never deployed on tenant. |
| Drift detection | conductor | PackInstance Drifted condition when manifests diverge from PackReceipt. |
| Federation channel | conductor | Audit forwarding from tenant conductor to management guardian. Implemented, never tested. |
| CAPI path | platform | SeamInfrastructureCluster and SeamInfrastructureMachine lifecycle. Unit tests for CAPI provisioning path added (session/10c). e2e on live cluster pending TENANT-CLUSTER-E2E. |
| IdentityBinding | guardian | IdentityProvider and IdentityBinding e2e with Keycloak or Dex. |
| SeamMembership live | seam-core/guardian | SeamMembership CRs admitted by guardian on live cluster. Compiler emits them in phase 01. Never verified on lab. |

---

## Roadmap (Future Sessions, Not Current Sprint)

| ID | Description |
|----|-------------|
| VORTEX-CLI | Implement ont history, ont graph, ont delta commands against Guardian-authorized audit sink. Specification complete in companion documents. |
| APP-CORE | Scaffold app-core repository with 9 CRDs. Required before Vortex SeamMembership. |
| DOCUMENTATION-CLUSTER | Sovereign cluster for unified cross-domain lineage graph. Follows Vortex retrieval interface. |
| ONTAR-SPEC | Formalize PermissionSnapshot pod contract schema in seam-core/docs/ontar-spec.md. After alpha release and first production fintech operator. |
| SCREEN | VirtCluster and VirtMachine CRDs. CAPI path to QEMU/KVM via libvirt and KubeVirt. |
| SERVICEMONITOR | Prometheus ServiceMonitor CRDs for all five operators. Deferred to post-e2e observability session. |
| CAPI-E2E-TESTS | e2e tests for SeamInfrastructureCluster/Machine lifecycle against live cluster. |

---

## Closed (Reference Only)

| ID | Description | Closed |
|----|-------------|--------|
| PLATFORM-BL-CAPI-DERIVED-LINEAGE | SetDescendantLabels wired on SeamInfrastructureCluster, CAPI Cluster, TalosControlPlane, MachineDeployment. ClusterProvision rationale. root-ili-namespace label enables cross-ns ILI lookup. 4 unit tests. platform f7a310c. | 2026-04-21 |
| GUARDIAN-BL-RBAC-INTAKE | POST /rbac-intake handler implemented. Compiler enable submits third-party RBAC resources; Guardian stamps ontai.dev/rbac-owner=guardian via SSA. 5 unit tests. guardian c0c41fb. | 2026-04-21 |
| ARCH-BL-RUNNERCONFIG-UNIFICATION | Ephemeral pack-delivery RunnerConfig eliminated. ClusterPackReconciler creates PackExecution directly. | session commit 51fd2ec |
| F-P9 | DSNS controller implementation in seam-core. | session/44+45 |
| F-P8 | Compiler enable phase 0 CNPG implementation. | session/43 |
| Gap-31 | Condition vocabulary drift across operators. | session/39 |
| C-32 | Bootstrap secret name doubles cluster prefix. | d22bbe5 |
| C-35 | Compiler bootstrap with machineConfigPaths emits talosconfig secret. | f340f80 |
| C-36 | BootstrapSequence not a Kubernetes CRD. Now a ConfigMap. | a735b49 |
| PACKINSTANCE-VERSION | PackInstance.spec.version not populated. DNS showed unknown. | WS6 |
| EPG-AUTO-REFRESH | PermissionSnapshot auto-refreshes when stale via EPG watch. | 22e7c75 |
| CONDUCTOR-CAPABILITY-REWATCH | Conductor republishes capabilities when RunnerConfig recreated. | 2c55a3b |
| CNPG-BOOTSTRAP-ANNOTATION-SWEEP | SSA wiped system ClusterRoles. Fixed with MergePatch. | 1da7e64 |
| CI-SCRIPT | enable-ccs-mgmt.sh committed to conductor/scripts/. Dry-run verified. | 2026-04-19 |
| SEAM-CORE-BL-LINEAGE | PackInstance test added (seam-core 52de8d3). PermissionSnapshot LineageSynced init removed (guardian c36ffd3). Regression guards added both repos. | 2026-04-19 |
| AC-1 | Management cluster import acceptance contract. 5 unit tests (platform). 5 e2e stubs skip until MGMT_KUBECONFIG. platform commit d4e7f26. | 2026-04-20 |
| AC-2 | ClusterPack deploy gate chain acceptance contract. 5 gate unit tests (wrapper). 5 EPG predicate tests (guardian). 7 e2e stubs each skip until TENANT-CLUSTER-E2E. wrapper ebb327d; guardian a89242e. | 2026-04-20 |
| AC-3 | Guardian audit sweep acceptance contract. 4 unit tests covering LazyAuditWriter and 2 controller audit actions. 5 e2e stubs skip until GUARDIAN-BL-ENVTEST-FAIL closed. guardian c78f474. | 2026-04-20 |
| AC-4 | LineageController manifest tracking acceptance contract. 5 unit tests covering ILI creation, LineageSynced transition, governance annotation, idempotency, 9 GVKs. 7 e2e stubs skip until TENANT-CLUSTER-E2E. seam-core e4d2cfa. | 2026-04-20 |
| AC-5 | DSNS lineage tracking acceptance contract. 6 unit tests covering all 4 CRD families and zone integrity. 7 e2e stubs skip until TENANT-CLUSTER-E2E. seam-core 96724b8. | 2026-04-20 |
| AC-DAY2 | Day-2 operational reconcilers acceptance contract. 21 platform unit tests, 2 integration tests, 32 e2e stubs across 8 reconcilers. EtcdMaintenance PVCFallbackEnabled field added. HardeningProfile Valid condition added. platform cd38ebd, 7f5da7d; conductor 4e52c9c. | 2026-04-20 |
| SEAM-CORE-BL-DESCENDANT-APPEND | seam-core DescendantReconciler: watches RunnerConfig GVK, appends DescendantEntry to ILI on root-ili label. SetDescendantLabels helper in pkg/lineage. 3 unit tests. seam-core 8312ad7. | 2026-04-20 |

# ONT Platform: Backlog

**Last updated:** April 18, 2026
**Branch:** session/1-governor-init (all repos)

Priority: High / Medium / Low

---

## Critical (Blocks Alpha Release)

| ID | Component | Description |
|----|-----------|-------------|
| CI-SCRIPT | conductor | enable-ccs-mgmt.sh not committed. Platform is not reproducible. Blocker for alpha release. |
| SEAM-CORE-BL-LINEAGE | seam-core | LineageSynced=False on PermissionSnapshot and PackInstance. LineageController not indexing all GVKs. Blocker for Vortex retrieval interface. |
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. |

---

## High Priority

| ID | Component | Description |
|----|-----------|-------------|
| PLATFORM-BL-TENANT-GC | platform | TalosCluster deletion should cascade to seam-tenant namespace via ownerReference Kubernetes GC. |
| G-BL-CR-IMMUTABILITY | guardian | Guardian webhook must block human patches on operator-created CRs: PackInstance, RunnerConfig, PermissionSnapshot, PackExecution. |
| G-BL-CNPG-POOLER-AUTH | guardian | Connect to rw service not pooler to avoid md5 hash caching on guardian restart. Engineer session drafted. |
| C-COREDNS-PATCH | compiler | coredns-dsns-patch.sh must be run manually after phase 05. Needs integration into CI script. |
| C-KUEUE-WEBHOOK | compiler | Kueue mutating webhook scoping must be automated after deployment. Needs CI script. |

---

## Medium Priority

| ID | Component | Description |
|----|-----------|-------------|
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | PackInstance deletion must trigger ClusterPack reconcile with PackExecution cascade delete. Fixed in 51fd2ec. Verify no regression after ARCH-BL-RUNNERCONFIG-UNIFICATION. |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | platform | TalosClusterReconciler status patch conflicts under 2-replica deployment. Use RetryOnConflict. |
| PLATFORM-BL-3-LOCALQUEUE | platform | Platform must create LocalQueue in seam-tenant for tenant clusters. Currently only management cluster gets it from compiler phase 05. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | Wrapper ConductorReady gate should watch RunnerConfig status and trigger immediately when capabilities appear rather than polling on 30s requeue. |
| G-BL-SNAPSHOT-ALIAS | guardian | snapshot-management should cover ccs-mgmt for management cluster. Eliminates redundant snapshot-ccs-mgmt. |
| G-BL-IDP-POLLING | guardian | IdentityProviderReconciler must poll OIDC provider for group membership changes and record identitybinding.drift_detected. Requires Keycloak or Dex in lab. |
| G-BL-SELF-AUDIT-MISSING | guardian | rbacprofile.provisioned and rbac.would_deny not in audit trail. Investigate LazyAuditWriter event dropping. |

---

## Low Priority / Polish

| ID | Component | Description |
|----|-----------|-------------|
| CONDUCTOR-BL-EXECUTION-ORDER | conductor | Staged manifest apply confirmed implemented. Verify with multi-manifest pack test. |
| WRAPPER-BL-PACKINSTANCE-VERSION-DOUBLE-V | wrapper | Ready condition message says vv0.1.2 double v prefix. Fixed in 51fd2ec. Verify. |
| C-34 | compiler | capi.controlPlane: {} noise in TalosCluster CR when capi.enabled=false. |
| CONDUCTOR-BL-RESULT-CM-TTL | conductor | OperationResult ConfigMap TTL. Fixed in 6d31b77. Verify GC happening. |

---

## Not Yet Tested

| Area | Component | Description |
|------|-----------|-------------|
| PackReceipt | conductor | Conductor agent on tenant cluster creating PackReceipt. Never deployed on tenant. |
| Drift detection | conductor | PackInstance Drifted condition when manifests diverge from PackReceipt. |
| Federation channel | conductor | Audit forwarding from tenant conductor to management guardian. Implemented, never tested. |
| CAPI path | platform | SeamInfrastructureCluster and SeamInfrastructureMachine lifecycle. Never tested. |
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

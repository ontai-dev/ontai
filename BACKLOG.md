# ONT Platform: Backlog

**Last updated:** April 26, 2026 (session/15 round 5 closures)

---

## Critical (Blocks Alpha Release)

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. Phase B script ready. Promotes all AC-2, AC-4, AC-5 e2e stubs to live. T-19 (platform state machine) and T-19a (guardian conductor-tenant profile) implemented in PRs #17 and #18 -- onboarding will no longer stall at ConductorPending. CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION (conductor pull loop) still required for full handshake but not a stall condition. |
| TCOR-SIZE-BOUND | conductor, platform | TCOR Operations map grows unbounded within a talosVersion epoch. At 500 bytes/entry, 3000 entries reach etcd 1.5MB limit. Mitigation: add mid-epoch flush in AppendOperationRecord when len(operations) >= 1000 (dump to GraphQuery without bumping revision). Blocked on CONDUCTOR-BL-GRAPHQUERY-ARCHIVE. Low risk for production (typical epochs see <100 operations). |
| TCOR-GRAPHQUERY-LINK | seam-core, GraphQuery | No explicit FK between PackOperationResult and TCOR across revisions. Implicit join key: clusterRef + talosVersion + revision. When GraphQuery archival is implemented, add graphQueryRevisionRef field to TCOR and POR to make the linkage explicit. Blocked on GraphQuery DB implementation. |

---

## High Priority

| ID | Component | Description |
|----|-----------|-------------|
| CONDUCTOR-BL-CAPABILITY-IMPL | conductor | All named capability handlers implemented. Validated live: etcd-defrag, node-reboot, pki-rotate, machine-config-capture. Unit tested: talos-upgrade, kube-upgrade, stack-upgrade, node-patch, node-scale-up, node-decommission, credential-rotate, cluster-reset, hardening-apply, pack-deploy, etcd-backup, etcd-restore (session/15 round 4). Remaining: etcd-backup and etcd-restore require live S3 object storage for e2e validation. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor, guardian | Conductor role=tenant must pull RBACProfile for its cluster from management cluster seam-tenant-{tenantCluster} and write it into ont-system on the tenant cluster. Management conductor (role=management) retains signing. Requires: conductor role field, federation pull path, ont-system write. Governor design session required before implementation. See GAP_TO_FILL.md T-19a. |
| DAY2-OPS-MGMT | conductor, platform | Remaining day-2 live gaps on ccs-mgmt: node-patch needs patchSecretRef secret provisioned; cluster-reset not live-tested (requires reset-approved annotation); upgrade, credential-rotate, hardening-apply not yet live-tested. etcd-defrag, node-reboot, pki-rotate already validated. |

---

## Medium Priority

| ID | Component | Description |
|----|-----------|-------------|
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | No admission webhook intercepts RBACProfile admission on any cluster. RBACProfile is absent from guardian webhook InterceptedKinds. The seam-operator label (ontai.dev/rbac-profile-type=seam-operator) is intended to discriminate seam operator profiles from component profiles, but no webhook routing implements this today. Fix: add a RBACProfile validation webhook that (a) checks the label, (b) routes seam-operator profiles through management-maximum validation, (c) routes all others through cluster-policy. See GAP_TO_FILL.md T-25a. |
| GUARDIAN-BL-RBACPROFILE-SWEEP | guardian | T-04b covers unprovisioned RBACProfiles only (retry failed intake writes). CONFIRMED GAP (T-25b, 2026-04-26): raw RBAC objects (ClusterRole, ClusterRoleBinding) arriving outside /rbac-intake/pack with no RBACProfile are invisible to the backfill runnable. Needs a new sweep reconciler that lists governed RBAC in seam-tenant-* and creates missing RBACProfiles. Design session required. GAP_TO_FILL.md T-25b. |
| WRAPPER-BL-ILI-DECLARING-PRINCIPAL | guardian, wrapper | MutatingWebhookConfiguration for declaring-principal handler added to compiler enable bundle. Needs cluster apply and verification against live admission webhook. |
| ~~PLATFORM-BL-3-LOCALQUEUE~~ | platform | CLOSED 2026-04-26: ensureTenantOnboarding creates LocalQueue pack-deploy-queue in seam-tenant-{cluster} on each tenant cluster import. Unit test TestTalosClusterReconcile_TenantImport_CreatesLocalQueue covers this. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | Wrapper ConductorReady gate should watch RunnerConfig status and trigger immediately when capabilities appear, rather than polling on 30s requeue. |
| G-BL-SNAPSHOT-ALIAS | guardian | snapshot-management PermissionSnapshot should cover ccs-mgmt. Eliminates redundant snapshot-ccs-mgmt. |
| G-BL-IDP-POLLING | guardian | IdentityProviderReconciler must poll OIDC provider for group membership changes and record identitybinding.drift_detected. Requires Keycloak or Dex in lab. |
| G-BL-SELF-AUDIT-MISSING | guardian | rbac.would_deny audit event absent. rbacprofile.provisioned and lineageIndexRef on governed-object events are wired. rbac.would_deny requires investigation of the deny path in the admission webhook handler. |
| PLATFORM-BL-HARDENINGPROFILE-MERGE | platform | HardeningProfileRef field absent from TalosClusterSpec. TalosConfigTemplate cannot merge HardeningProfile patches at runtime. Decision 11: schema PR to ontai-schema required before implementation. Governor session needed. |
| SEAM-CORE-BL-DESCENDANT-LABELS | guardian | PermissionSnapshot lineage wiring deferred by design (no single root RBACPolicy per snapshot). If architectural question resolves, PermissionSnapshot must call SetDescendantLabels. Track until Governor rules. |
| WRAPPER-BL-ENVTEST-GC | wrapper | TestPackInstance_OwnerRefCascade_DeletedWhenPackExecutionDeleted requires kube-controller-manager GC. envtest does not start GC controller. Promote to live cluster e2e when TENANT-CLUSTER-E2E is established. |

---

## Low Priority / Polish

| ID | Component | Description |
|----|-----------|-------------|
| CONDUCTOR-BL-EXECUTION-ORDER | conductor | Staged manifest apply confirmed implemented. Verify with multi-manifest pack test. |

---

## Not Yet Tested (Live Cluster)

| Area | Component | Description |
|------|-----------|-------------|
| PackReceipt | conductor | Conductor agent on tenant cluster creating PackReceipt. Never deployed on a tenant cluster. |
| Drift detection | conductor | PackInstance Drifted condition when manifests diverge from PackReceipt. Requires tenant conductor deployed and active. |
| Federation channel | conductor | Audit forwarding from tenant conductor to management guardian. Implemented, never tested. |
| CAPI path | platform | SeamInfrastructureCluster and SeamInfrastructureMachine full lifecycle. Unit tests exist. e2e on live cluster pending TENANT-CLUSTER-E2E. |
| IdentityBinding | guardian | IdentityProvider and IdentityBinding e2e with Keycloak or Dex. No lab IdP provisioned. |
| SeamMembership live | seam-core, guardian | SeamMembership CRs admitted by guardian on live cluster. Compiler emits them in phase 01. Never verified on lab. |
| Day-2 ops live (remaining) | conductor, platform | cluster-reset, upgrade, credential-rotate, hardening-apply not yet live-tested. node-patch full e2e blocked by patchSecretRef. |

---

## Roadmap (Future, Not Current Sprint)

| ID | Description |
|----|-------------|
| VORTEX-CLI | ont history, ont graph, ont delta commands against Guardian-authorized audit sink. Specification complete. |
| APP-CORE | Scaffold app-core repository with 9 CRDs. Required before Vortex SeamMembership. |
| DOCUMENTATION-CLUSTER | Sovereign cluster for unified cross-domain lineage graph. Follows Vortex retrieval interface. |
| ONTAR-SPEC | Formalize PermissionSnapshot pod contract schema in seam-core/docs/ontar-spec.md. After alpha release and first production fintech operator adoption. |
| SCREEN | VirtCluster and VirtMachine CRDs. CAPI path to QEMU/KVM via libvirt and KubeVirt. INV-021: no implementation until Governor-approved ADR. |
| SERVICEMONITOR | Prometheus ServiceMonitor CRDs for all five operators. Deferred to post-e2e observability session. |
| CAPI-E2E-TESTS | e2e tests for SeamInfrastructureCluster/Machine full lifecycle against live cluster. |

---

## Closed

| ID | Component | Closed | Resolution |
|----|-----------|--------|------------|
| COMPILER-BL-PERMISSIONSET-DEFECT | conductor (compiler) | 2026-04-26 | writeBootstrapPermissionSets now emits only management-maximum. buildOperatorRBACProfile now emits permissionSetRef: management-maximum. Both enable bundles regenerated. Per-operator PermissionSets deleted from live cluster. conductor PR #26. |
| GUARDIAN-BL-PERMISSIONSET-WATCH | guardian | 2026-04-26 | Watches(PermissionSet, MapPermissionSetToProfiles) added to RBACProfileReconciler.SetupWithManager. 5 unit tests added. guardian session/15-guardian-fixes commit 1881ccf. |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | platform | 2026-04-26 | RetryOnConflict already implemented in taloscluster_controller.go deferred status patch (line 112). Verified session/15 -- no code change required. |
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | 2026-04-26 | Phase 2B GVK (InfrastructurePackInstance) was correct. MapPackInstanceToClusterPack exported; 4 unit tests added. wrapper PR #15. |
| WRAPPER-BL-PACKINSTANCE-VERSION-DOUBLE-V | wrapper | 2026-04-26 | Verified post-Phase 2B: version comes directly from ClusterPackRef.Version with no extra prefix. Existing test covers. No code change required. |
| PLATFORM-BL-3-LOCALQUEUE | platform | 2026-04-26 | ensureTenantOnboarding creates LocalQueue in seam-tenant-{cluster} for every tenant cluster. Unit test TestTalosClusterReconcile_TenantImport_CreatesLocalQueue. Already implemented. |

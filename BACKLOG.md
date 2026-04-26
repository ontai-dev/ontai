# ONT Platform: Backlog

**Last updated:** April 26, 2026 (session/15 round 1 closures)

---

## Critical (Blocks Alpha Release)

| ID | Component | Description |
|----|-----------|-------------|
| TENANT-CLUSTER-E2E | all | ccs-dev never onboarded as tenant cluster. Required for alpha. Phase B script ready. Promotes all AC-2, AC-4, AC-5 e2e stubs to live. |
| TCOR-SIZE-BOUND | conductor, platform | TCOR Operations map grows unbounded within a talosVersion epoch. At 500 bytes/entry, 3000 entries reach etcd 1.5MB limit. Mitigation: add mid-epoch flush in AppendOperationRecord when len(operations) >= 1000 (dump to GraphQuery without bumping revision). Blocked on CONDUCTOR-BL-GRAPHQUERY-ARCHIVE. Low risk for production (typical epochs see <100 operations). |
| TCOR-GRAPHQUERY-LINK | seam-core, GraphQuery | No explicit FK between PackOperationResult and TCOR across revisions. Implicit join key: clusterRef + talosVersion + revision. When GraphQuery archival is implemented, add graphQueryRevisionRef field to TCOR and POR to make the linkage explicit. Blocked on GraphQuery DB implementation. |

---

## High Priority

| ID | Component | Description |
|----|-----------|-------------|
| ~~COMPILER-BL-PERMISSIONSET-DEFECT~~ | conductor (compiler) | CLOSED 2026-04-26: writeBootstrapPermissionSets now emits only management-maximum. buildOperatorRBACProfile now emits permissionSetRef: management-maximum. Both enable bundles regenerated. Per-operator PermissionSets deleted from live cluster. conductor PR #26 merged. |
| CONDUCTOR-BL-CAPABILITY-IMPL | conductor | Named capability handlers need completion. Implemented and validated: etcd-defrag, node-reboot, pki-rotate (GetMachineConfig+staged), machine config capture after node-patch. Remaining stubs: etcd-backup, etcd-restore, node-scale-up, node-decommission, credential-rotate, cluster-reset, hardening-apply, upgrade, pack-deploy. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor, guardian | Conductor role=tenant must pull RBACProfile for its cluster from management cluster seam-tenant-{tenantCluster} and write it into ont-system on the tenant cluster. Management conductor (role=management) retains signing. Requires: conductor role field, federation pull path, ont-system write. Governor design session required before implementation. |
| DAY2-OPS-MGMT | conductor, platform | Remaining day-2 live gaps on ccs-mgmt: node-patch needs patchSecretRef secret provisioned; cluster-reset not live-tested (requires reset-approved annotation); upgrade, credential-rotate, hardening-apply not yet live-tested. etcd-defrag, node-reboot, pki-rotate already validated. |

---

## Medium Priority

| ID | Component | Description |
|----|-----------|-------------|
| ~~GUARDIAN-BL-PERMISSIONSET-WATCH~~ | guardian | CLOSED 2026-04-26: Watches(PermissionSet, MapPermissionSetToProfiles) added to RBACProfileReconciler.SetupWithManager. 5 unit tests added. guardian branch session/15-guardian-fixes commit 1881ccf. |
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | No admission webhook intercepts RBACProfile admission on any cluster. RBACProfile is absent from guardian webhook InterceptedKinds. The seam-operator label (ontai.dev/rbac-profile-type=seam-operator) is intended to discriminate seam operator profiles from component profiles, but no webhook routing implements this today. Fix: add a RBACProfile validation webhook that (a) checks the label, (b) routes seam-operator profiles through management-maximum validation, (c) routes all others through cluster-policy. Documented in guardian-schema.md §20 validation bypass note. |
| GUARDIAN-BL-RBACPROFILE-SWEEP | guardian | No reconciler creates RBACProfiles for RBAC resources arriving outside /rbac-intake/pack (bootstrap apply, kubectl apply, pre-split packs). Sweep must detect governed RBAC with no corresponding RBACProfile and back-fill it. Design question: same PermissionSet/RBACPolicy/RBACProfile path as rbac-intake, or lightweight annotation-only path. Governor session required. |
| WRAPPER-BL-ILI-DECLARING-PRINCIPAL | guardian, wrapper | MutatingWebhookConfiguration for declaring-principal handler added to compiler enable bundle. Needs cluster apply and verification against live admission webhook. |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | platform | TalosClusterReconciler status patch conflicts under 2-replica deployment. Needs RetryOnConflict. |
| PLATFORM-BL-3-LOCALQUEUE | platform | Platform must create LocalQueue in seam-tenant for tenant clusters. Currently only management cluster gets it from compiler phase 05. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | Wrapper ConductorReady gate should watch RunnerConfig status and trigger immediately when capabilities appear, rather than polling on 30s requeue. |
| G-BL-SNAPSHOT-ALIAS | guardian | snapshot-management PermissionSnapshot should cover ccs-mgmt. Eliminates redundant snapshot-ccs-mgmt. |
| G-BL-IDP-POLLING | guardian | IdentityProviderReconciler must poll OIDC provider for group membership changes and record identitybinding.drift_detected. Requires Keycloak or Dex in lab. |
| G-BL-SELF-AUDIT-MISSING | guardian | rbac.would_deny audit event absent. rbacprofile.provisioned and lineageIndexRef on governed-object events are wired. rbac.would_deny requires investigation of the deny path in the admission webhook handler. |
| PLATFORM-BL-HARDENINGPROFILE-MERGE | platform | HardeningProfileRef field absent from TalosClusterSpec. TalosConfigTemplate cannot merge HardeningProfile patches at runtime. Decision 11: schema PR to ontai-schema required before implementation. Governor session needed. |
| SEAM-CORE-BL-DESCENDANT-LABELS | guardian | PermissionSnapshot lineage wiring deferred by design (no single root RBACPolicy per snapshot). If architectural question resolves, PermissionSnapshot must call SetDescendantLabels. Track until Governor rules. |
| WRAPPER-BL-ENVTEST-GC | wrapper | TestPackInstance_OwnerRefCascade_DeletedWhenPackExecutionDeleted requires kube-controller-manager GC. envtest does not start GC controller. Promote to live cluster e2e when TENANT-CLUSTER-E2E is established. |
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | Verify PackInstance deletion still triggers ClusterPack reconcile with PackExecution cascade delete after Phase 2B GVK changes. |

---

## Low Priority / Polish

| ID | Component | Description |
|----|-----------|-------------|
| CONDUCTOR-BL-EXECUTION-ORDER | conductor | Staged manifest apply confirmed implemented. Verify with multi-manifest pack test. |
| WRAPPER-BL-PACKINSTANCE-VERSION-DOUBLE-V | wrapper | Ready condition message has vv0.1.2 double-v prefix. Verify fix from 51fd2ec still applies post Phase 2B. |

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

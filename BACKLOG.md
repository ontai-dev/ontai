# ONT Platform: Backlog

**Last updated:** 2026-05-02 (session/17 e2e run results recorded; DAY2-OPS-TENANT updated; etcd backup/restore closed)

---

## Critical (Blocks Alpha Release)

| ID | Component | Description |
|----|-----------|-------------|
| TCOR-SIZE-BOUND | conductor, platform | TCOR Operations map grows unbounded within a talosVersion epoch. At 500 bytes/entry, 3000 entries reach the etcd 1.5MB limit. Mitigation: add mid-epoch flush in AppendOperationRecord when len(operations) >= 1000 (dump to GraphQuery without bumping revision). Blocked on CONDUCTOR-BL-GRAPHQUERY-ARCHIVE. Low risk for current lab scale (typical epochs see fewer than 100 operations). |

---

## High Priority

| ID | Component | Description |
|----|-----------|-------------|
| DAY2-OPS-TENANT | conductor, platform | Remaining day-2 live validation gaps after session/17 e2e run: hardening-apply MGMT-HP-NODE failed (cp3 down, infra); TENANT-HP-CLUSTER and TENANT-HP-NODE blocked (ccs-dev unreachable); TENANT-PKI-CLUSTER-REACH blocked (ccs-dev unreachable). Passed: MGMT-HP-CLUSTER, MGMT-HP-PROFILE, TENANT-HP-PROFILE, TENANT-PKI-ROTATE. Etcd backup/restore validated session/17 Task C. conductor-execute:dev image current (7c4c47d). Unblocked when cp3 stable and ccs-dev reachable. |
| MGMT-HP-NODE-DESIGN | conductor, platform | `mgmtWorkerNode = "ccs-mgmt-w2"` hardcoded in `platform/test/e2e/day2/hardeningprofile_e2e_test.go` does not exist on ccs-mgmt. `TargetNodes` in `NodeMaintenanceSpec` governs Job pod scheduling exclusion only (NotIn affinity rule); `hardeningApplyHandler` applies to all talosconfig endpoints regardless. Decide: either update test to use an existing node, or implement per-target-node filtering in `hardeningApplyHandler` using `TargetNodes` params. |
| PLATFORM-BL-HARDENINGPROFILE-MERGE | platform | HardeningProfileRef field absent from TalosClusterSpec. TalosConfigTemplate cannot merge HardeningProfile patches at runtime. Decision 11: schema PR to ontai-schema required before implementation. Governor session needed. Also blocks mode=bootstrap machineconfig generation from spec. |
| PLATFORM-BL-MACHINECONFIG-IMPORT-CAPTURE | platform | For mode=import clusters, Platform should capture machineconfigs from running nodes via Talos COSI API GetMachineConfig and write them as seam-mc-{cluster}-{hostname} Secrets in seam-tenant-{cluster}. Requires: node discovery from target kubeconfig, talos goclient per-node call (CP-INV-001 extension for taloscluster_import_helpers.go), new ensureMachineConfigSecrets function. |
| T-23 | platform | Platform DriftSignal handling for cluster-state drift. Design session required. See GAP_TO_FILL.md. |
| T-24 | platform, conductor | TalosCluster deletion cascade per Decision H order. Design session required. See GAP_TO_FILL.md. |

---

## Medium Priority

| ID | Component | Description |
|----|-----------|-------------|
| GUARDIAN-BL-RBACPROFILE-SWEEP | guardian | Needs a sweep reconciler that lists governed RBAC in seam-tenant-* and creates missing RBACProfiles for raw RBAC objects (ClusterRole, ClusterRoleBinding) arriving outside /rbac-intake/pack with no RBACProfile. Design session required. |
| GUARDIAN-BL-RBACPROFILE-WEBHOOK | guardian | RBACProfile added to InterceptedKinds (T-25a closed). Webhook validation: seam-operator label profiles must reference management-maximum only. Gate 4a implemented. Verify live against admission webhook. |
| WRAPPER-BL-ILI-DECLARING-PRINCIPAL | guardian, wrapper | MutatingWebhookConfiguration for declaring-principal handler added to compiler enable bundle. Needs cluster apply and live verification. |
| CONDUCTOR-BL-CAPABILITY-WATCH | conductor | Wrapper ConductorReady gate polls on 30s requeue. Should watch RunnerConfig status and trigger immediately when capabilities appear. |
| G-BL-SNAPSHOT-ALIAS | guardian | snapshot-management PermissionSnapshot should cover ccs-mgmt to eliminate redundant snapshot-ccs-mgmt. |
| G-BL-IDP-POLLING | guardian | IdentityProviderReconciler must poll OIDC provider for group membership changes. Requires Keycloak or Dex in lab. |
| G-BL-SELF-AUDIT-MISSING | guardian | rbac.would_deny audit event absent. Needs investigation of deny path in admission webhook handler. |
| SEAM-CORE-BL-DESCENDANT-LABELS | guardian | PermissionSnapshot lineage wiring deferred. Track until Governor rules on whether there is a single root RBACPolicy per snapshot. |
| WRAPPER-BL-ENVTEST-GC | wrapper | TestPackInstance_OwnerRefCascade_DeletedWhenPackExecutionDeleted requires kube-controller-manager GC not available in envtest. Promote to live cluster e2e. |

---

## Not Yet Tested (Live Cluster)

| Area | Component | Description |
|------|-----------|-------------|
| HardeningProfile live (TENANT) | platform, conductor | MGMT specs passed session/17. TENANT-HP-CLUSTER and TENANT-HP-NODE blocked until ccs-dev reachable. MGMT-HP-NODE blocked until cp3 stable and test updated (MGMT-HP-NODE-DESIGN). |
| PKI rotation live (TENANT reach) | platform, conductor | TENANT-PKI-ROTATE passed session/17. TENANT-PKI-CLUSTER-REACH blocked until ccs-dev reachable (pack-deploy Job cannot connect to ccs-dev). |
| Federation channel | conductor | Audit forwarding from tenant conductor to management guardian. Implemented, never tested. |
| CAPI path | platform | SeamInfrastructureCluster and SeamInfrastructureMachine full lifecycle. Unit tests exist. e2e not yet scheduled. |
| IdentityBinding | guardian | IdentityProvider and IdentityBinding e2e with Keycloak or Dex. No lab IdP provisioned. |
| SeamMembership live | seam-core, guardian | SeamMembership CRs admitted by guardian on live cluster. Compiler emits them in phase 01. Never verified on lab. |
| ClusterReset live | platform | Requires reset-approved annotation. Deliberately not live-tested to avoid cluster destruction. |

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
| GUARDIAN-AUTO-RBAC | For every new API group detected on a cluster, guardian should upgrade seam-operator RBACProfile/PermissionSets on both tenant and management clusters. Governor request 2026-05-02. |

---

## Closed

| ID | Component | Closed | Resolution |
|----|-----------|--------|------------|
| DAY2-ETCD-S3-LIVE | conductor, platform | 2026-05-02 | Etcd backup and restore Jobs validated live on ccs-dev session/17 Task C. S3 credential injection in platform (s3_env_secret.go) and bytes.Reader upload fix in conductor both shipped. Both Jobs completed Ready=True. |
| CLUSTERPACK-BL-VERSION-CLEANUP | conductor | 2026-05-02 | deleteOrphanedResources() + deployedResourceKey() in packinstance_pull_loop.go. 2 unit tests. |
| CONDUCTOR-BL-TENANT-ROLE-RBACPROFILE-DISTRIBUTION | conductor | 2026-05-02 | RBACProfilePullLoop in rbacprofile_pull_loop.go. 4 unit tests. |
| PLATFORM-BL-WRAPPER-RUNNER-RBAC-LIFECYCLE | platform | 2026-05-02 | finalizerWrapperRunnerCRBCleanup + Step 3 in handleTalosClusterDeletion. |
| TENANT-CLUSTER-E2E | all | 2026-05-01 | Full ccs-dev lifecycle validated: ClusterPack deploy, PackReceipt, drift loop, orphan teardown, fresh redeploy, rollback. |
| CONDUCTOR-BL-DRIFT-SIGNAL | conductor | 2026-05-01 | PackReceiptDriftLoop + DriftSignalHandler. 14 unit tests. Live: 3 retrigger cycles, TerminalDrift, confirmed state. |
| COMPILER-BL-PERMISSIONSET-DEFECT | conductor | 2026-04-26 | writeBootstrapPermissionSets emits only management-maximum. Both enable bundles regenerated. |
| GUARDIAN-BL-PERMISSIONSET-WATCH | guardian | 2026-04-26 | Watches(PermissionSet, MapPermissionSetToProfiles) added. 5 unit tests. |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | platform | 2026-04-26 | RetryOnConflict already implemented. No code change required. |
| WRAPPER-BL-PACKINSTANCE-WATCH | wrapper | 2026-04-26 | GVK correct post-Phase 2B. 4 unit tests. |
| PLATFORM-BL-3-LOCALQUEUE | platform | 2026-04-26 | ensureTenantOnboarding creates LocalQueue. Unit test added. |
| CONDUCTOR-BL-SIGNING-KEY-TENANT | conductor | 2026-05-01 | --signing-private-key rejected for --cluster-role=tenant. ccs-dev bundle: private key removed. |
| GUARDIAN-BL-RBACPROFILE-TENANT-PROVISIONING | guardian | 2026-05-01 | reconcileTenantSnapshotPath() in RBACProfileReconciler. |

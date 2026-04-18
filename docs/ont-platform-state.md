# ONT Platform: Current State, Backlogs and Path to Vortex

**Author:** Krishna
**Roles:** SRE, Platform Engineer, Infrastructure Governance Engineer
**Date:** April 12, 2026
**Branch:** session/1-governor-init (all repos)

---

## Part 1: What is Working Today

### Management Cluster (ccs-mgmt) End to End

The management cluster bring-up sequence is confirmed working from a clean Talos cluster through full pack delivery. The following gates pass without manual intervention after applying the enable bundle.

**Bootstrap and Import**

Compiler bootstrap with machineConfigPaths and talosconfig flag generates all machineconfig secrets, the talosconfig secret, and the TalosCluster CR with correct mode, role, talosVersion, and clusterEndpoint fields. TalosCluster import reaches Ready within seconds of applying. Platform auto-onboards the cluster: RBACPolicy allowedClusters updated, operator RBACProfiles targetClusters updated, LocalQueue created in seam-tenant, target-cluster-kubeconfig copied.

**Guardian**

RBACPolicy reconciles pre-existing objects on startup via the startup runnable. All five operator RBACProfiles provision automatically. EPG computes PermissionSnapshots with 3600s freshness window. Snapshots auto-refresh when stale via the EPG watch on PermissionSnapshot Fresh condition. CNPG is connected and 197+ audit events are written across five action types: rbacpolicy.validated, epg.computation_complete, permissionsnapshot.computed, permissionsnapshot.drift_detected, bootstrap.annotation_sweep_complete.

**Conductor**

Capability publisher retries until RunnerConfig exists and republishes when RunnerConfig is deleted and recreated. All 17 capabilities publish to the cluster anchor RunnerConfig within 15 seconds of RunnerConfig creation. Signing loop signs ClusterPacks automatically.

**Pack Delivery**

ClusterPack created with targetClusters triggers PackExecution creation directly from ClusterPackReconciler without an ephemeral RunnerConfig. All four gates clear automatically: ConductorReady, PackSignaturePending, PermissionSnapshotOutOfSync, RBACProfileNotProvisioned. Kueue Job runs, conductor-execute applies manifests, PackInstance created with correct version field. DNS TXT record emitted at pack.{name}.{version}.wrapper.{cluster}.seam.ontave.dev with value "delivered".

**DNS**

All five record types resolve correctly: SOA, A for cluster VIP, A for API endpoint, TXT for role, TXT for pack delivery with version. NS glue record uses live LoadBalancer IP from Cilium. Records clean up on ClusterPack or TalosCluster deletion via finalizers.

**Schema Integrity**

Traceability chain locked: DomainRelationship (domain-core) traces to DomainIdentityRef (RBACProfile) traces to InfrastructureLineageIndex.domainRef (seam-core) traces to SeamMembership (admitted by guardian). Six Seam operator DomainRelationships declared in domain-core. SeamMembership CRD in seam-core. SeamMembershipReconciler in guardian validates domainIdentityRef match and RBACProfile provisioned gate before admitting.

---

## Part 2: Known Bugs and Active Fixes

| ID | Component | Description | Status |
|----|-----------|-------------|--------|
| CNPG-POOLER-AUTH | guardian | Password auth fails on guardian rollout. Pooler caches md5 hash. Fix: bypass pooler, connect to rw service directly. | Engineer session drafted |
| COMPILER-TALOSCONFIG | conductor | Compiler bootstrap with machineConfigPaths not reliably emitting talosconfig secret. Covered in f340f80 but needs verification on next clean test. | Verify |
| PACKINSTANCE-DOUBLE-V | wrapper | Ready condition message says "vv0.1.2" double v prefix. Fixed in 51fd2ec. | Verify |
| RBACPROFILE-MISSING-ACTIONS | guardian | rbacprofile.provisioned and rbac.would_deny not appearing in audit_events. LazyAuditWriter may drop events before CNPG connects. | Investigate |

---

## Part 3: Open Backlogs by Component

### Conductor

| ID | Description | Priority |
|----|-------------|----------|
| CONDUCTOR-BL-CAPABILITY-WATCH | Wrapper ConductorReady gate should watch RunnerConfig status and trigger immediately when capabilities appear rather than polling on 30s requeue. | Medium |
| CONDUCTOR-BL-EXECUTION-ORDER | Staged manifest apply confirmed implemented. Verify with multi-manifest pack test. | Low |

### Guardian

| ID | Description | Priority |
|----|-------------|----------|
| G-BL-CNPG-POOLER-AUTH | Connect to rw service not pooler to avoid md5 hash caching on restart. | High |
| G-BL-CR-IMMUTABILITY | Guardian webhook must block human patches on operator-created CRs: PackInstance, RunnerConfig, PermissionSnapshot, PackExecution. | High |
| G-BL-SNAPSHOT-ALIAS | snapshot-management should cover ccs-mgmt for management cluster. Eliminates redundant snapshot-ccs-mgmt. | Medium |
| G-BL-IDP-POLLING | IdentityProviderReconciler must poll OIDC provider for group membership changes and record identitybinding.drift_detected. | Medium |
| G-BL-SELF-AUDIT-MISSING | rbacprofile.provisioned and rbac.would_deny not in audit trail. Investigate LazyAuditWriter event dropping. | Medium |

### Platform

| ID | Description | Priority |
|----|-------------|----------|
| PLATFORM-BL-TENANT-GC | TalosCluster deletion should cascade to seam-tenant namespace and all ClusterPacks within it via ownerReference Kubernetes GC. | High |
| PLATFORM-BL-STATUS-PATCH-CONFLICT | TalosClusterReconciler status patch conflicts under 2-replica deployment. Use RetryOnConflict. | Medium |
| PLATFORM-BL-3-LOCALQUEUE | Platform must create LocalQueue in seam-tenant for tenant clusters. Currently only management cluster gets it from compiler phase 05. | Medium |

### Wrapper

| ID | Description | Priority |
|----|-------------|----------|
| WRAPPER-BL-PACKINSTANCE-WATCH | PackInstance deletion must trigger ClusterPack reconcile with PackExecution cascade delete. Fixed in 51fd2ec. Verify. | High |
| ARCH-BL-RUNNERCONFIG-UNIFICATION | Ephemeral pack-delivery RunnerConfig in seam-tenant is eliminated. ClusterPackReconciler creates PackExecution directly. Verify no regression. | High |

### Compiler

| ID | Description | Priority |
|----|-------------|----------|
| C-COREDNS-PATCH | coredns-dsns-patch.sh must be run manually after phase 05. Needs integration into CI script. | High |
| C-KUEUE-WEBHOOK | Kueue mutating webhook scoping must be automated after deployment. Needs CI script integration. | High |
| C-BOOTSTRAP-SEQUENCE | bootstrap-sequence.yaml ConfigMap must explicitly name talosconfig secret in step 1. Fixed in f340f80. Verify. | Medium |

### seam-core

| ID | Description | Priority |
|----|-------------|----------|
| SEAM-CORE-BL-LINEAGE | LineageSynced=False on PermissionSnapshot and PackInstance. LineageController not indexing all GVKs. | Medium |

---

## Part 4: What is Not Yet Tested

| Area | Description |
|------|-------------|
| Tenant cluster onboarding | ccs-dev as a second cluster imported and receiving ClusterPacks. |
| PackReceipt | Conductor agent on tenant cluster creating PackReceipt. |
| Drift detection | PackInstance Drifted condition when manifests diverge from PackReceipt. |
| Federation channel | Audit forwarding from tenant conductor to management guardian. |
| CAPI path | SeamInfrastructureCluster and SeamInfrastructureMachine lifecycle. |
| IdentityBinding | IdentityProvider and IdentityBinding e2e with Keycloak or Dex. |
| SeamMembership live | SeamMembership CRs admitted by guardian on live cluster. |

---

## Part 5: CI Automation Gap

The enable-ccs-mgmt.sh script is drafted but not committed. It must cover the following.

Phase sequencing: 00-infrastructure-dependencies, 00a-namespaces, 01-guardian-bootstrap, 02-guardian-deploy (with caBundle refresh), 03-platform-wrapper, Kueue deployment with webhook scoping, 04-conductor, 05-post-bootstrap with CoreDNS patch script, TalosCluster import.

Readiness gates between phases: CNPG operator available, guardian ready and RBACProfiles provisioned, platform and wrapper and seam-core leaders elected, conductor capabilities published, TalosCluster Ready, DNS records resolving.

Manual steps that must be automated before alpha: CoreDNS dsns stanza patch, Kueue webhook namespace scoping, talosconfig Secret application before TalosCluster CR.

---

## Part 6: Schema Integrity Chain (Current State)

The traceability chain is now formally locked through the following artifacts.

```
DomainRelationship (domain-core/config/relationships/)
  6 YAML declarations: guardian-signs-conductor, conductor-signs-clusterpack,
  platform-creates-runnerconfig, wrapper-creates-packexecution,
  guardian-provisions-rbacprofile, seam-core-tracks-lineage

DomainIdentityRef (guardian RBACProfileSpec)
  Set by compiler enable for all 6 operators.
  Traces each operator SA to its DomainIdentity at core.ontai.dev.

InfrastructureLineageIndex.spec.domainRef (seam-core)
  Set by LineageController to "infrastructure.core.ontai.dev".
  Validated at CREATE by admission webhook.

SeamMembership (seam-core CRD, guardian reconciler)
  Compiler emits 5 SeamMembership CRs in phase 01.
  Guardian SeamMembershipReconciler validates domainIdentityRef match
  and RBACProfile provisioned gate, then sets Admitted=True.

PermissionSnapshot (guardian)
  PermissionSnapshotRef set after membership admission.
  Operator is formally admitted to Seam family.
```

---

## Part 7: Path to Vortex

Vortex is the human-at-boundary portal operator. It is an application-layer operator that joins the Seam family via SeamMembership. Its development requires the following prerequisites in strict sequential order.

**Prerequisite 1: Alpha release of current 5 repos**

Complete the CI script. Confirm clean ccs-mgmt enable from scratch with no manual patches. Confirm tenant cluster (ccs-dev) onboarding with one ClusterPack delivery end to end.

**Prerequisite 2: app-core repository**

The Application Operator Framework must be scaffolded in a new app-core repository. CRDs required: AppBoundary, AppIdentity, AppPolicy, AppTopology, AppEventSchema, AppWorkflow, AppResourceProfile, AppAuditPolicy, AppProfile. These CRDs translate domain-core primitives into application-layer declarations. Vortex is the first consumer. domain-core and app-core must be released open source together with the Seam operator family.

**Prerequisite 3: Vortex SeamMembership**

Vortex submits an AppProfile. Guardian evaluates AppPolicy against DomainPolicy ceiling. SeamMembership declares tier=application. Guardian admits and resolves a Seam-tier PermissionSnapshot granting Vortex read access across tenant CRDs scoped by its AppBoundary.

**Prerequisite 4: Vortex AppTopology wiring**

Three structural wirings declared in Vortex AppTopology, each tracing to a DomainRelationship authority: Guardian gRPC PermissionService (SnapshotBinding, trust-critical), GitOps webhook endpoint (ContinuousBinding, operational), CNPG database instance (SnapshotBinding, schema-pinned).

**Prerequisite 5: Vortex UI**

Portal surface covering AppProfile authoring with AI-curated manifest generation, RelationshipAdmissionRequest human approval workflow, cluster topology visualization via DSNS, drift detection surfacing from PackInstance.

---

## Part 8: App-Core and ONT Schema Pullbacks

The ONT schema document defines the full application domain framework. The following gaps exist relative to that document and are deferred until app-core development begins.

| Gap | Impact | Deferred Until |
|-----|--------|----------------|
| AppBoundary and AppIdentity CRDs do not exist | No application operator can join the Seam family via AppProfile | app-core scaffolding |
| DomainRelationship has no reconciler | AppTopology entries have no runtime authority validation | app-core scaffolding |
| RelationshipClass seven-condition admission not enforced | Bounded candidate resolution not implemented | app-core scaffolding |
| Guardian webhook does not enforce topology wiring validity | AppPolicy ceiling and AppAuditPolicy floor not checked | app-core scaffolding |
| TemporalRelationship lifecycle not in Conductor | Ephemeral workflow dependencies have no admission tracking | app-core scaffolding |
| DSNS does not resolve by relationship class | Semantic resolution not implemented beyond A and TXT records | Vortex phase |
| AppObservability injection not implemented | No automated observability wiring into application pods | Post-alpha |

---

## Part 9: ONT Philosophy Anchors

These invariants must be preserved through all future development.

Every infrastructure operation is declarative, versioned, and auditable. No operator acts without a governing policy. No trust is self-declared. Every relationship traces to a DomainRelationship authority. AI accelerates R and D but humans remain at every production boundary. The management cluster is the sovereign trust root. Compiler never deploys. Compiler produces manifests for human review and GitOps application only.

The Seam family operators are the first and most authoritative consumers of the application domain framework. They do not receive exemptions from it.

Vortex is not just a UI. It is the proof point: the portal that governs application configuration is itself governed by every rule it enforces.

---

*Document generated: April 12, 2026*
*Repos: conductor, guardian, platform, wrapper, seam-core, domain-core*
*Branch: session/1-governor-init*

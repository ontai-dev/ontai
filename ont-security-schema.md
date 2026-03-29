# ont-security-schema
> API Group: security.ontai.dev
> Operator: ont-security
> All agents absorb this document. Security is platform-wide.

---

## 1. Domain Boundary

ont-security owns all RBAC across the entire platform — management cluster and
every target cluster. It is the only operator with cross-cutting authority. It
is the only operator with genuine in-process intelligence (EPG computation, policy
validation, admission webhook). It is the only operator with a CNPG dependency.

**Absolute rules with no exceptions:**
- No ONT operator or application implements its own authorization logic.
- No component provisions its own Kubernetes RBAC artifacts.
- All authorization flows through ont-security's PermissionService.
- ont-security's admission webhook gates every RBAC resource on every cluster.
- ont-security deploys first. All other operators wait for RBACProfile provisioned=true before being considered enabled. INV-003.

---

## 2. Namespace Placement

| Resource                   | Namespace                              |
|----------------------------|----------------------------------------|
| RBACPolicy                 | security-system (platform-admin only)  |
| RBACProfile                | tenant-{cluster-name}                  |
| IdentityBinding            | tenant namespace    |
| PermissionSet              | security-system                        |
| PermissionSnapshot         | security-system (internal)             |
| CNPG cluster               | security-system                        |
| PermissionSnapshotReceipt  | ont-system on target cluster           |

---

## 3. Two-Phase Boot

ont-security has a structured boot sequence to resolve the CNPG chicken-and-egg
problem. This is a named phase in the runner's enable protocol — not a silent
fallback.

**Phase 1 — CRD-only mode:**
ont-security starts with in-memory and CRD status persistence only. It provisions:
its own RBACProfile from the bootstrap RBACPolicy (compiled into git at compile
time), CNPG's RBAC, cert-manager's RBAC, Kueue's RBAC, metallb's RBAC. All state
held in CRD status. The runner enable phase installs these components in this window
with their RBAC already provisioned by ont-security before installation begins.

**Phase 2 — Database-backed mode:**
CNPG comes online. ont-security detects CNPG readiness, migrates EPG and audit
state to CNPG, switches to database-backed persistence. All subsequent EPG
computation and audit logging goes to CNPG.

The transition from Phase 1 to Phase 2 is atomic and idempotent. If the management
cluster is rebuilt, Phase 1 is re-executed and Phase 2 resumes once CNPG is healthy.

---

## 4. Bootstrap RBAC Window

Before ont-security's admission webhook is operational, the runner enable phase
must apply RBAC to install ont-security itself. This window is explicitly declared
in the enable phase protocol. The bootstrap RBACPolicy in git defines exactly what
is permitted in this window. As soon as ont-security's webhook becomes operational,
the window closes permanently. RBAC applied in this window is immediately reconciled
by ont-security on startup — validated and ownership-annotated if compliant, flagged
for remediation if not. INV-020.

---

## 5. Admission Webhook

ont-security runs an admission webhook on every cluster — management and all
target clusters. The webhook intercepts all creates and updates to: Role,
ClusterRole, RoleBinding, ClusterRoleBinding, ServiceAccount.

Any RBAC resource arriving without annotation ontai.dev/rbac-owner=ont-security
is rejected at admission with a structured error. The only path for RBAC resources
to land on any cluster is through ont-security taking ownership first.

On target clusters, the runner in agent mode runs the local webhook using the
current PermissionSnapshotReceipt as its authority. The target cluster's RBAC gate
is fully operational even when the management cluster is temporarily unreachable.

---

## 6. Third-Party RBAC Ownership

ont-security wraps third-party component RBAC — CNPG, cert-manager, Kueue, metallb,
and future components — into RBACProfiles with ownership annotations.

The model is wrapping, not replacement. Replacement would create a drift loop with
Helm chart upgrades. Instead:
- ont-security creates a RBACProfile declaring policy compliance for the component.
- Existing RBAC resources are annotated: ontai.dev/rbac-owner=ont-security.
- ont-security watches those resources. Drift from the declared RBACProfile raises
  a policy violation. It never silently overwrites.
- The runner splits compiled chart output into RBAC resources and workload resources.
  RBAC goes through ont-security intake. Workload applies directly.

---

## 7. CRDs — Management Cluster

### RBACPolicy

Scope: Namespaced — security-system. Platform-admin visibility only.
Short name: rp

Governing policy that constrains what RBACProfiles within its scope may declare.
Profiles that exceed their governing policy are rejected at admission.

The bootstrap RBACPolicy for the management cluster is generated by the runner
compile mode and committed to git alongside TalosCluster. It exists on the
management cluster before ont-security is installed.

Key spec fields: subjectScope, allowedClusters, maximumPermissionSetRef,
enforcementMode (strict or audit).

---

### RBACProfile

Scope: Namespaced — tenant-{cluster-name}
Short name: rbp

Per-component per-tenant permission declaration. Validated against governing
RBACPolicy before provisioned=true is set. No operator is enabled until its
RBACProfile reaches provisioned=true. INV-003.

Key spec fields: principalRef, targetClusters, permissionDeclarations,
rbacPolicyRef.

Status conditions: Provisioned, ValidationFailed, Pending.

Invariant: provisioned is set exclusively by ont-security. No other controller
writes to RBACProfile status.

---

### IdentityBinding

Scope: Namespaced.
Short name: ib

Maps external identity to ONT permission principal.
Key spec fields: identityType (oidc, serviceAccount, certificate), identity-specific
fields, principalName, trustMethod (mtls default, token requires justification and
max 15-minute TTL).

---

### PermissionSet

Scope: Namespaced — security-system.
Short name: ps

Named reusable permission collection. Platform archetypes created at initialization:
cluster-admin, tenant-admin, pack-executor, viewer.
Key spec fields: permissions (API group, resource, verbs), description.

---

### PermissionSnapshot

Scope: Namespaced — security-system. Internal to ont-security.
Short name: psn

Computed, versioned, signed EPG for a specific target cluster. Generated on any
input change. Never manually authored. One per target cluster, replaced in-place
on recomputation. Version field provides monotonic ordering.

Delivery tracking fields: expectedVersion, lastAckedVersion, drift, lastSeen.

---

## 8. CRDs — Target Cluster (Agent-Managed)

### PermissionSnapshotReceipt

Scope: Namespaced — ont-system on target cluster.
Short name: psr

Local record of current acknowledged PermissionSnapshot and provisioned RBAC
artifact status. Created and maintained exclusively by the runner in agent mode
acting as the security agent. Never authored manually.

One PermissionSnapshotReceipt per target cluster. If the management cluster is
rebuilt, it reconstructs delivery status by reading this CR on each cluster.

Key fields: snapshotVersion, acknowledgedAt, localProvisioningStatus,
localArtifacts, syncStatus (InSync, OutOfSync, DegradedSecurityState).

---

## 9. Permission Propagation

Push is optimization. Pull is correctness. Acknowledgement is truth.

**Delivery contract:** push snapshot → agent acknowledges → ont-security records.

**SnapshotOutOfSync:** acknowledgement not received within 2× TTL (default 10 min).
Consequence: new PackExecution blocked on affected cluster.

**DegradedSecurityState:** persistent failure beyond extended threshold.
Consequence: no new authorization decisions permitted. Human intervention required.

**Pull loop:** agent periodically compares local version against management cluster
expected version. Self-heals by pulling and acknowledging. Pull is the correctness
guarantee. Push is the performance optimization.

---

## 10. PermissionService gRPC API

Single runtime authorization decision point. All ONT operators and applications
call this service. No operator queries Kubernetes RBAC API directly.

Operations: CheckPermission, ListPermissions, WhoCanDo, ExplainDecision.

On target clusters: the runner agent in security mode exposes a local
PermissionService endpoint. Application operators on the target cluster call the
local agent. The agent serves decisions from its current PermissionSnapshotReceipt
without requiring management cluster connectivity. This is how future ont-virt and
application operators achieve runtime authorization without management cluster
network dependency.

PermissionService is the planned QuantAI integration point for AI-proposed
infrastructure operations requiring human gate review.

---

## 11. Execution Gatekeeper

All four conditions must pass before PackExecution is admitted to Kueue. Enforced
by ont-security's admission webhook — a hard block, not a soft check:

1. Target cluster has current, acknowledged PermissionSnapshot.
2. Requesting principal has validated, provisioned RBACProfile.
3. Target cluster is in principal's RBACProfile.targetClusters.
4. Requested operation is within principal's effective permission set.

---

## 12. Tenant Isolation

Three-layer isolation, each independent of the others:
1. Namespace isolation: tenant-{cluster-name} namespace boundary.
2. RBAC enforcement: tenants cannot list cluster-scoped resources globally.
3. Policy-level: ont-security validates targetCluster against allowedClusters at
   admission. Bypass via RBAC misconfiguration in layers 1 or 2 is impossible.

---

## 13. CNPG Security Warehouse Access Controls

NetworkPolicy restricts ingress to security-system to ont-security pods only.
CNPG credentials are Secrets in security-system with no RBAC bindings for human
users — not even cluster-admin can read them through normal paths.
Audit access for the security team is granted through a designated read-only view
exposed by ont-security's PermissionService — never through direct database access.

---

## 14. Cross-Domain Rules

Reads: platform.ontai.dev/QueueProfile to provision Kueue ClusterQueue resources.
Reads: platform.ontai.dev/TalosCluster to detect new cluster registrations and
  create initial RBACProfiles.
Reads: runner.ontai.dev/RunnerConfig status (capability confirmation).
Intercepts: infra.ontai.dev/PackExecution at admission (execution gatekeeper).
Writes: security.ontai.dev resources on management cluster.
Writes: PermissionSnapshotReceipt on target clusters via agent.
Writes: Kueue ClusterQueue and ResourceFlavor resources (derived from QueueProfile).
Never writes to platform.ontai.dev or infra.ontai.dev CRDs.

---

*security.ontai.dev schema — ont-security*
*Amendments appended below with date and rationale.*
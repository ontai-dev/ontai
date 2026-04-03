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
- ont-security deploys first. All other operators wait for RBACProfile provisioned=true
  before being considered enabled. INV-003.

**Deployment boundary:**
The ont-security controller (EPG computation, PermissionSnapshot generation, policy
validation, gRPC PermissionService) runs only on the management cluster in the
security-system namespace.

On target clusters, the security plane responsibilities — admission webhook,
PermissionSnapshot receipt, local PermissionService, RBAC enforcement — are
hosted by the ont-agent Deployment in ont-system. There is no separate ont-security
Deployment on target clusters. The ont-agent binary incorporates all target cluster
security plane functions. This is the zero-attack-surface model: one distroless
binary per cluster, no redundant deployments.

---

## 2. Namespace Placement

| Resource                   | Namespace                              |
|----------------------------|----------------------------------------|
| RBACPolicy                 | security-system (platform-admin only)  |
| RBACProfile                | tenant-{cluster-name}                  |
| IdentityBinding            | tenant namespace                       |
| PermissionSet              | security-system                        |
| PermissionSnapshot         | security-system (internal)             |
| CNPG cluster               | security-system                        |
| PermissionSnapshotReceipt  | ont-system on target cluster           |

---

## 3. Two-Phase Boot

ont-security has a structured boot sequence to resolve the CNPG chicken-and-egg
problem. This is a named phase in the ont-runner enable protocol — not a silent
fallback. This sequence applies only to the management cluster.

**Phase 1 — CRD-only mode:**
ont-security starts with in-memory and CRD status persistence only. It provisions:
its own RBACProfile from the bootstrap RBACPolicy (compiled into git at compile
time), CNPG's RBAC, cert-manager's RBAC, Kueue's RBAC, metallb's RBAC. All state
held in CRD status. The ont-runner enable phase installs these components in this
window with their RBAC already provisioned by ont-security before installation begins.

**Phase 2 — Database-backed mode:**
CNPG comes online. ont-security detects CNPG readiness, migrates EPG and audit
state to CNPG, switches to database-backed persistence. All subsequent EPG
computation and audit logging goes to CNPG.

The transition from Phase 1 to Phase 2 is atomic and idempotent. If the management
cluster is rebuilt, Phase 1 is re-executed and Phase 2 resumes once CNPG is healthy.

---

## 4. Bootstrap RBAC Window

Before ont-security's admission webhook is operational on the management cluster,
the ont-runner enable phase must apply RBAC to install ont-security itself. This
window is explicitly declared in the enable phase protocol. The bootstrap RBACPolicy
in git defines exactly what is permitted in this window. As soon as ont-security's
webhook becomes operational, the window closes permanently. RBAC applied in this
window is immediately reconciled by ont-security on startup — validated and
ownership-annotated if compliant, flagged for remediation if not. INV-020.

On target clusters, the bootstrap RBAC window is handled differently: the ont-agent
Deployment arrives via the agent ClusterPack deployment. Once the ont-agent starts
on a target cluster, its admission webhook is immediately operational. There is no
bootstrap RBAC window on target clusters — the agent pack is applied via the
agent bootstrap exception (ont-infra-schema.md Section 6) before any webhook exists,
and from that point forward the webhook runs continuously.

---

## 5. Admission Webhook

ont-security runs an admission webhook on the management cluster. The webhook
intercepts all creates and updates to: Role, ClusterRole, RoleBinding,
ClusterRoleBinding, ServiceAccount.

Any RBAC resource arriving without annotation ontai.dev/rbac-owner=ont-security
is rejected at admission with a structured error. The only path for RBAC resources
to land on the management cluster is through ont-security taking ownership first.

**On target clusters:** The admission webhook is hosted by the ont-agent Deployment
in ont-system, not by a separate ont-security controller. The ont-agent webhook
uses the current PermissionSnapshotReceipt as its authority for admission decisions.
This means target cluster RBAC enforcement is fully operational even when the
management cluster is temporarily unreachable — the ont-agent serves decisions
from its local acknowledged snapshot state.

The webhook behavior is identical on management and target clusters: any RBAC
resource lacking the ontai.dev/rbac-owner=ont-security annotation is rejected.
The implementation in ont-agent shares the webhook logic package from the shared
library.

---

## 6. Third-Party RBAC Ownership

ont-security wraps third-party component RBAC — CNPG, cert-manager, Kueue, metallb,
and future components — into RBACProfiles with ownership annotations.

The model is wrapping, not replacement:
- ont-security creates a RBACProfile declaring policy compliance for the component.
- Existing RBAC resources are annotated: ontai.dev/rbac-owner=ont-security.
- ont-security watches those resources. Drift from the declared RBACProfile raises
  a policy violation. It never silently overwrites.
- The ont-runner enable phase splits compiled chart output into RBAC resources and
  workload resources. RBAC goes through ont-security intake. Workload applies directly.

Any ONT operator joining the stack on the management cluster must, by default, request
RBAC from ont-security before its controller starts. The RBACProfile gate (provisioned=true)
blocks all operator controllers until ont-security has validated and provisioned their
permission declarations. INV-003.

---

## 7. CRDs — Management Cluster

### RBACPolicy

Scope: Namespaced — security-system. Platform-admin visibility only.
Short name: rp

Governing policy that constrains what RBACProfiles within its scope may declare.
Profiles that exceed their governing policy are rejected at admission.

The bootstrap RBACPolicy for the management cluster is generated by ont-runner
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

Invariant: provisioned=true is set exclusively by ont-security. No other controller
writes to RBACProfile status. CS-INV-005.

---

### IdentityBinding

Scope: Namespaced.
Short name: ib

Maps external identity to ONT permission principal.
Key spec fields: identityType (oidc, serviceAccount, certificate), identity-specific
fields, principalName, trustMethod (mtls default, token requires justification and
max 15-minute TTL).

---

### IdentityProvider

Scope: Namespaced — security-system.
Short name: idp

Declares an external identity source whose assertions Guardian will recognize and
validate. This is distinct from IdentityBinding: IdentityProvider configures the
upstream source — SSO provider, PKI certificate authority, token issuer, OIDC
endpoint — while IdentityBinding maps a specific identity from that source to a
platform permission principal. One IdentityProvider per external identity source.
Multiple IdentityBindings may reference the same IdentityProvider.

Key spec fields: type (oidc, pki, token), issuerURL (for OIDC providers), caBundle
(for PKI providers), tokenSigningKey (for token issuers), allowedAudiences,
validationRules.

Status conditions: Reachable, ValidationFailed, Pending.

**Relationship to IdentityBinding:** Guardian validates IdentityBinding trust
assertions against the IdentityProvider declared for that identity type. An
IdentityBinding without a matching IdentityProvider for its identityType is
rejected at admission. The IdentityProvider is the upstream trust anchor. The
IdentityBinding is the principal assignment.

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
input change by the EPGReconciler. Signed by the management cluster ont-agent
after generation. Never manually authored. One per target cluster, replaced
in-place on recomputation. Version field provides monotonic ordering.

Delivery tracking fields: expectedVersion, lastAckedVersion, drift, lastSeen.

The signature annotation (ontai.dev/snapshot-signature) is written by the management
cluster ont-agent signing loop, not by the EPGReconciler. Operators and reconcilers
must not write this annotation. It is validated by target cluster ont-agent before
receipt acknowledgement.

---

## 8. CRDs — Target Cluster (ont-agent Managed)

All CRDs in this section are created and maintained exclusively by the ont-agent
Deployment in ont-system on the target cluster. No separate ont-security agent
exists on target clusters. ont-agent incorporates all target cluster security plane
responsibilities.

### PermissionSnapshotReceipt

Scope: Namespaced — ont-system on target cluster.
Short name: psr

Local record of current acknowledged PermissionSnapshot and provisioned RBAC
artifact status. Created and maintained exclusively by ont-agent in agent mode.
Never authored manually.

Before writing a receipt acknowledgement, ont-agent verifies the cryptographic
signature on the PermissionSnapshot against the platform public key embedded in
the ont-agent binary. Verification failure results in SyncStatus=DegradedSecurityState
and does not advance lastAckedVersion. This prevents a compromised management cluster
from pushing malicious permission snapshots to target clusters.

One PermissionSnapshotReceipt per target cluster. If the management cluster is
rebuilt, it reconstructs delivery status by reading this CR on each cluster.

Key fields (agent-managed): snapshotVersion, acknowledgedAt, localProvisioningStatus,
localArtifacts, syncStatus (InSync, OutOfSync, DegradedSecurityState).

---

## 9. Permission Propagation

Push is optimization. Pull is correctness. Acknowledgement is truth.
Verification is trust.

**Delivery contract:** sign snapshot → push snapshot → agent verifies signature →
agent acknowledges → ont-security records.

**SnapshotOutOfSync:** acknowledgement not received within 2× TTL (default 10 min).
Consequence: new PackExecution blocked on affected cluster.

**DegradedSecurityState:** persistent failure beyond extended threshold, or signature
verification failure.
Consequence: no new authorization decisions permitted. Human intervention required.

**Pull loop:** ont-agent periodically compares local version against management cluster
expected version. Self-heals by pulling and re-verifying. Pull is the correctness
guarantee. Push is the performance optimization.

---

## 10. PermissionService gRPC API

Single runtime authorization decision point. All ONT operators and applications
call this service. No operator queries Kubernetes RBAC API directly.

Operations: CheckPermission, ListPermissions, WhoCanDo, ExplainDecision.

**On management cluster:** the ont-security controller exposes the PermissionService
gRPC endpoint backed by the current in-memory EPG (backed by CNPG).

**On target clusters:** ont-agent in agent mode exposes a local PermissionService
gRPC endpoint in ont-system. Application operators and controllers on the target
cluster call the local agent endpoint. The agent serves decisions from its current
acknowledged PermissionSnapshotReceipt without requiring management cluster
connectivity. This is how future ont-virt and application operators achieve runtime
authorization without management cluster network dependency.

The local PermissionService implementation in ont-agent is a read-only projection
of the acknowledged snapshot — it does not compute the EPG. EPG computation is
exclusively a management cluster function in the ont-security controller.

PermissionService is the planned QuantAI integration point for AI-proposed
infrastructure operations requiring human gate review.

---

## 11. Execution Gatekeeper

All four conditions must pass before PackExecution is admitted to Kueue. Enforced
by ont-security's admission webhook on the management cluster — a hard block, not
a soft check:

1. Target cluster has current, acknowledged, verified PermissionSnapshot.
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
Writes: PermissionSnapshotReceipt on target clusters via ont-agent.
Writes: Kueue ClusterQueue and ResourceFlavor resources (derived from QueueProfile).
Never writes to platform.ontai.dev or infra.ontai.dev CRDs.

The signing annotation (ontai.dev/snapshot-signature) on PermissionSnapshot is
written by the management cluster ont-agent, not by the ont-security controller.
The controller generates the snapshot. The agent signs it. These are sequential,
not concurrent writes.

---

*security.ontai.dev schema — ont-security*
*Amendments appended below with date and rationale.*

2026-03-30 — Target cluster security plane responsibilities transferred to ont-agent.
  No separate ont-security Deployment on target clusters. ont-agent hosts admission
  webhook, PermissionSnapshotReceipt management, local PermissionService, and drift
  detection on target clusters. Cryptographic signing model added: management cluster
  ont-agent signs PermissionSnapshot; target cluster ont-agent verifies before
  acknowledgement. Section 1 domain boundary clarified. Section 5 admission webhook
  updated for two-context model. Section 8 receipt management updated to name ont-agent
  explicitly. Section 10 PermissionService split into management and target context.
  INV-026 referenced.

2026-04-03 — IdentityProvider CRD added to Section 7. Relationship to IdentityBinding
  formally specified. IdentityProvider is the upstream trust anchor. IdentityBinding is
  the principal assignment. An IdentityBinding without a matching IdentityProvider for
  its identityType is rejected at admission. IdentityProvider is a prerequisite before
  any Controller Engineer session implementing identity trust methods in IdentityBinding.
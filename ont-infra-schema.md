# ont-infra-schema
> API Group: infra.ontai.dev
> Operator: ont-infra
> Absorb before any design or implementation work touching pack compile or delivery.

---

## 1. Domain Boundary

ont-infra owns compile-time resolution of Helm charts, Kustomize overlays, and
raw manifests into immutable ClusterPack artifacts, and the runtime delivery of
those artifacts to target clusters via runner Jobs.

ont-infra is a thin reconciler. Its pattern is identical to all ONT operators:
watch CR → read RunnerConfig → confirm named capability → build Job spec → submit
to Kueue → read OperationResult → update CR status.

ont-infra is the only operator that triggers compile-time pack building. No other
operator invokes Helm or Kustomize in any form. Runtime delivers only pre-rendered
Kubernetes manifests. This is absolute.

Compile intelligence: all in the runner.
Runtime intelligence: none. The runner applies manifests. It does not interpret them.

---

## 2. The Compile / Runtime Boundary

**Compile time (runner compile mode, never a Job):**
Helm chart rendering, Kustomize overlay resolution, manifest normalization,
RBAC generation, execution order computation, image digest pinning, checksum
computation, OCI registry push. The output is an immutable ClusterPack artifact.

**Runtime (runner executor mode as Kueue Job):**
Fetch ClusterPack from registry. Verify checksum. Apply manifests in declared
execution order using server-side apply. Monitor readiness per stage. Write
OperationResult. Exit. No rendering. No decisions.

---

## 3. CRDs — Management Cluster

### PackBuild

Scope: Namespaced — infra-system
Short name: pb
Lives in: git and management cluster.

Compile trigger. Human authors PackBuild in git. On GitOps apply it lands on the
management cluster. ont-infra generates RunnerConfig from PackBuild spec using
the shared runner library and submits a compile capability Job.

Key spec fields:
- source.helm: chart repo URL, chart name, version, values as structured data.
- source.kustomize: overlay path reference.
- source.raw: list of raw manifest references.
- targetVersion: version string to assign to produced ClusterPack.

Status conditions: Compiling, Ready (records ClusterPack name and digest), Failed.

PackBuild does not own the ClusterPack it produces. ClusterPack is an independent
CR that records the build provenance.

---

### ClusterPack

Scope: Namespaced — infra-system
Short name: cp
Lives in: OCI registry (artifact) and management cluster (tracking CR).

Immutable deployment artifact record. The CR is not the artifact — it tracks the
artifact at a specific digest in the OCI registry. Once registered, a versioned
ClusterPack is never modified. Changes require a new PackBuild producing a new
ClusterPack version.

Key spec fields:
- version: declared version string.
- registryRef: OCI registry URL and digest.
- checksum: content-addressed checksum.
- sourceRef: PackBuild CR that produced this ClusterPack.
- executionOrder: stage ordering from compiled execution graph.
  Stages: rbac → storage → stateful → stateless.
- lifecyclePolicies: resource retention rules for upgrade and delete.
- provenance: build identity, timestamp, source digests, signature reference.

ClusterPack spec never contains: Helm templates, Kustomize overlays, variable
references, runtime decision logic. Their presence is an invariant violation.

Status conditions: Available, Revoked.

---

### PackExecution

Scope: Namespaced — infra-system
Short name: pe
Named capability: pack-deploy

Runtime request to apply a specific ClusterPack version to a specific target cluster.
Contains no execution logic. A pure reference that the PackExecution controller
acts on by submitting a runner Job.

Gates before Job submission (all enforced by ont-security admission webhook):
- Target cluster PermissionSnapshot is current and acknowledged.
- Requesting principal's RBACProfile is provisioned and permits this operation.
- ClusterPack version is not revoked.

Key spec fields: clusterPackRef, targetClusterRef, admissionProfileRef.
Status conditions: Pending, Running, Succeeded, Failed.

---

### PackInstance

Scope: Namespaced — infra-system
Short name: pi

Tracks currently deployed state of a specific pack on a specific target cluster.
One PackInstance per pack per target cluster. Continuously compares expected state
from ClusterPack with PackReceipt drift status reported by the infra agent.

Key spec fields:
- clusterPackRef: currently active ClusterPack name and version.
- targetClusterRef: target cluster this instance tracks.
- dependsOn: list of PackInstance names that must be Ready before this is deployable.
- dependencyPolicy.onDrift: Block (default infra), Warn (default app), Ignore.

Status conditions: Ready, Progressing, Drifted, DependencyBlocked.

---

## 4. CRDs — Target Cluster (Agent-Managed)

### PackReceipt

Scope: Namespaced — ont-system on target cluster
Short name: pr

Local record of deployed ClusterPack versions and drift status. Created and
maintained exclusively by the ont-runner in agent mode acting as the infra agent.
Never authored by humans or other controllers.

One PackReceipt per deployed pack per target cluster. The management cluster's
PackInstance trusts PackReceipt as its source of delivery confirmation.

Key fields (agent-managed): packRef, appliedAt, checksum, driftStatus (Clean or
Drifted), driftDetails, lastCheckedAt.

---

## 5. Upgrade and Rollback

**Upgrade flow:** New ClusterPack version is compiled and registered. New
PackExecution references new version. Runner diff engine computes resource delta.

| Resource condition         | Action                            |
|----------------------------|-----------------------------------|
| Exists in both versions    | Patch via server-side apply       |
| Only in current version    | Apply lifecycle policy            |
| Only in target version     | Create                            |

Lifecycle policies: retain, delete, orphan, replace.
PVCs default to retain. StatefulSets default to retain.
Breaking stateful changes require explicit human approval gate.

**Rollback:** PackExecution referencing a previous ClusterPack version. Same diff
engine and execution order. No special reverse logic — artifacts are immutable.

---

## 6. Agent Bootstrap Exception

The agent ClusterPack is the first pack applied to any target cluster. During
bootstrap, the runner applies it directly via kube goclient without going through
the PackExecution flow. No PackReceipt tracking exists yet because no infra agent
is present. This is the single documented exception to the normal pack delivery
model. After the agent pack is applied, all subsequent deliveries follow the
normal PackExecution model.

---

## 7. Drift Detection

The runner in agent mode runs periodic server-side dry-run comparisons between
the expected state from the current PackReceipt and actual live cluster state.
Updates PackReceipt drift status. PackInstance on the management cluster reflects
this via its Drifted condition. Remediation is a runner Job — the agent never
auto-remediates without an explicit PackExecution.

---

## 8. Cross-Domain Rules

Reads: security.ontai.dev/PermissionSnapshot delivery status before admitting
PackExecution. Does not write to security.ontai.dev.
Reads: platform.ontai.dev/ClusterAssignment to determine which ClusterPack version
is bound to which cluster. Does not write to platform.ontai.dev.
Reads: runner.ontai.dev/RunnerConfig status (capability confirmation).
Writes: runner.ontai.dev/RunnerConfig (generates from PackBuild spec).
Writes: infra.ontai.dev resources on management cluster.
Writes: PackReceipt on target clusters via the runner agent.

---

*infra.ontai.dev schema — ont-infra*
*Amendments appended below with date and rationale.*
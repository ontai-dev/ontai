# ont-runner-schema
> API Group: runner.ontai.dev
> Component: ont-runner binary
> All agents absorb this document. Runner is the execution authority.

---

## 1. Central Principle

ont-runner is the platform intelligence. Operators are thin reconcilers.
All execution logic — compile-time and runtime — lives in the runner binary.

Human-facing compile operations are invocations of the ont-runner binary in
compile mode. Cluster management operations are performed by submitting ONT
CRs which operators translate into runner Jobs.

---

## 2. Binary Architecture

The runner is a single Go binary. No shell invocations. No external tool
dependencies. All clients are pure Go library integrations.

**Embedded Go clients:**
- talos goclient: all Talos API interactions. Executor and agent modes only
  after bootstrap completes. Never in compile mode. INV-013.
- kube goclient: all Kubernetes API interactions. All modes.
- helm goclient: Helm chart rendering. Compile mode only. INV-014.
- kustomize goclient: overlay resolution. Compile mode only. INV-014.

**Three modes — no other modes exist:**

| Mode     | Invocation              | Duration    | Cluster connection |
|----------|-------------------------|-------------|--------------------|
| compile  | Direct binary invocation| Short-lived | Not required       |
| executor | Kueue Job pod           | Short-lived | Required (mounted) |
| agent    | Deployment in ont-system| Long-lived  | Local cluster      |

Mode is determined by startup flag and RunnerConfig mounted at startup.
Invoking helm goclient or kustomize goclient in executor or agent mode is a
programming error and the runner exits with a structured failure immediately.

---

## 3. Runner Tag Convention

**Stable releases:** v{talosVersion}-r{revision}
The talosVersion component declares Talos API compatibility — not cosmetic.
A cluster at Talos v1.9.3 must use a runner tagged v1.9.3-rN. This is a hard
compatibility requirement. INV-012.

**Development:** dev (floating), dev-rc{N} (release candidates).

**Lab builds:** same convention, pushed only to 10.20.0.1:5000/ontai-dev/ont-runner. 
Lab tags never appear in the public registry. INV-011.

Updating RunnerConfig to the new runner tag is a prerequisite to any Talos version
upgrade. The upgrade reconciler checks this gate before submitting any upgrade Job.

---

## 4. Shared Runner Library

The shared runner library is owned by ont-runner and imported by all operators.
It is the single source of RunnerConfig schema, generation logic, and capability
manifest structure. This library is how operators generate RunnerConfig at runtime
from TalosCluster or PackBuild spec without duplicating logic.

**Library exports:**
- RunnerConfig schema types
- GenerateFromTalosCluster(spec) → RunnerConfig
- GenerateFromPackBuild(spec) → RunnerConfig
- CapabilityManifest types
- OperationResult types
- Job spec builder functions

When the runner adds a new named capability, it updates the shared library.
Operators get the new capability by updating their library dependency version.
No operator logic changes are required for new capabilities.

---

## 5. CRDs

### RunnerConfig

Scope: Namespaced — ont-system (management cluster), tenant-{cluster-name} (targets).
Short name: rc

The live operational contract between operators and the runner for a specific
cluster or pack. Operator-generated at runtime using the shared library. Never
human-authored. Never a compile-time artifact.

Key spec fields:
- clusterRef: cluster identity this RunnerConfig governs.
- runnerImage: fully qualified runner image including tag. Single source of truth
  for which runner version handles this cluster's Jobs.
- licenseSecretRef: optional reference to a JWT license Secret. Required for
  clusters beyond the community tier limit (3 clusters).
- phases: applicable phases for this cluster (launch, enable for management;
  launch, bootstrap for tenant clusters).
- operationalHistory: append-only record of every configuration change applied.
  Never deleted, only superseded by newer entries for the same concern.

Per-phase parameter sections:
- launch: vmConfig, talosInstallerImage, networkConfig, bootstrapTimeout.
- enable: prerequisiteTimeout, operatorTimeout. Management cluster only.
- bootstrap: agentPackRef, agentNamespace, retryLimit. Tenant clusters only.

Status fields (runner agent populates):
- capabilities: the self-declared capability manifest. List of named capabilities
  the current runnerImage supports, each with version and parameter schema.
  Operators read this before submitting Jobs. If capability absent: raise
  CapabilityUnavailable on the operational CR and wait.
- agentVersion: the runner image version currently running as agent.
- agentLeader: the pod name currently holding the leader election lease.
- licenseStatus: Community, Licensed, LicenseExpired, LicenseConstraint.
  LicenseConstraint means this cluster exceeds the community tier limit and has
  no valid license. The agent refuses to start for this cluster.

Status conditions: LaunchComplete, EnableComplete, BootstrapComplete, PhaseFailed,
CapabilityUnavailable, LicenseConstraint.

---

### OperatorManifest

Scope: Namespaced — ont-system. Management cluster only.
Short name: om

Declares one operator for the runner's enable phase to install. Not used for
tenant cluster operator installation — that is ClusterPack delivery.

The bootstrap RBACPolicy that is available before ont-security installs must
authorize the enable phase operations declared here.

Key spec fields:
- operatorName: canonical name matching repository name.
- version: Helm chart version to install.
- chartRef: chart repository URL and chart name.
- installNamespace: namespace on management cluster.
- ownedCRDs: list of CRD names for post-installation verification.
- requiredCRDs: CRD names that must be registered before installation.
- requiredSecrets: Secrets that must exist before installation.
- upgradeStrategy: RollingUpgrade or RecreateOnChange.
- installOrder: integer defining enable phase sequence. Lower installs first.
  Prerequisites use order 0. ont-security must always be order 1. This is enforced
  by the runner — any OperatorManifest with installOrder 1 that is not ont-security
  is a programming error.

Status conditions: Installed, Healthy, Failed.

The runner processes OperatorManifests in ascending installOrder sequence. It does
not proceed to the next until the current reaches Healthy. This enforces ont-security
deployment priority and all subsequent dependency ordering.

---

## 6. Named Capabilities

Named capabilities are the runner's execution vocabulary. Every operator Job maps
to exactly one named capability. New capabilities are added to the runner binary
and declared in the shared library. No operator code changes are required.

**Capability invocation contract:**
The operator stamps the capability name into the Job spec as an environment variable.
The runner reads the capability name on startup in executor mode and executes the
corresponding implementation. The runner exits with a structured OperationResult.

**Current named capabilities:**

| Capability          | Owner operator  | Description                              |
|---------------------|-----------------|------------------------------------------|
| bootstrap           | ont-platform    | Full cluster bootstrap from seed nodes   |
| talos-upgrade       | ont-platform    | Rolling Talos OS version upgrade         |
| kube-upgrade        | ont-platform    | Kubernetes version upgrade               |
| stack-upgrade       | ont-platform    | Coordinated Talos OS + Kubernetes upgrade|
| node-patch          | ont-platform    | Machine config patch to nodes            |
| node-scale-up       | ont-platform    | Add nodes to existing cluster            |
| node-decommission   | ont-platform    | Cordon, drain, remove node               |
| node-reboot         | ont-platform    | Reboot nodes                             |
| etcd-backup         | ont-platform    | etcd snapshot + config export to S3      |
| etcd-maintenance    | ont-platform    | etcd defrag and optional snapshot        |
| etcd-restore        | ont-platform    | Disaster recovery from S3 snapshot       |
| pki-rotate          | ont-platform    | PKI certificate rotation                 |
| credential-rotate   | ont-platform    | Service account key rotation             |
| hardening-apply     | ont-platform    | Apply TalosHardeningProfile              |
| cluster-reset       | ont-platform    | Destructive factory reset with human gate|
| pack-compile        | ont-infra       | Compile PackBuild into ClusterPack       |
| pack-deploy         | ont-infra       | Apply ClusterPack to target cluster      |
| rbac-provision      | ont-security    | Provision RBAC artifacts from snapshot   |

**Future-proofing:** When a new named capability is added to the runner binary, it
is declared in the shared library's capability manifest. Operators discover it via
RunnerConfig status. No operator requires changes. New capabilities are additive
and backward-compatible with existing operator deployments.

---

## 7. Inter-Job State — Temporary PVC Protocol

For multi-step sequence capabilities (bootstrap, stack-upgrade, cluster-reset),
the runner uses a temporary PVC for inter-step state transfer.

Protocol:
1. First Job creates a PVC named ont-{capability}-{cr-name}. Executes step.
   Writes intermediate artifacts to PVC. Updates operational CR status.
2. Subsequent Jobs mount the same PVC. Read previous step outputs. Execute step.
   Write outputs. Update status.
3. Final Job consumes all intermediate artifacts. Creates Kubernetes assets on
   management cluster. Deletes PVC. Writes terminal OperationResult.

The operator never sees the PVC. It only sees CR status advancing. The runner
manages PVC lifecycle entirely within the Job sequence. Storage class requirement:
the management cluster must have a storage class available (local-path-provisioner
in the lab environment satisfies this).

---

## 8. OperationResult Protocol

Every runner Job writes an OperationResult JSON document to a ConfigMap before
exit. ConfigMap name derived from Job name. The operator reads it to advance CR
status. No other inter-process communication channel exists between operator and
runner.

Structure: phase, status (succeeded or failed), startedAt, completedAt, artifacts
(structured references — never raw content), failureReason (category and detail
when failed), steps (individual step results for multi-step capabilities).

The operator must read OperationResult within the Job's configured TTL. After TTL
expiry the ConfigMap is garbage collected. The operator is responsible for acting
before expiry.

---

## 9. Compile Mode

Human invokes: ont-runner compile [cluster|pack] --input <path> --output <path>

For cluster compilation:
1. Read TalosCluster spec and human-provided machineconfig files.
2. Validate TalosCluster spec against ~/ontai/ont-platform-schema.md rules.
3. Validate machineconfig structure against the declared Talos version.
4. SOPS-encrypt talos-secret, machineconfigs, talosconfig using admin's age key.
5. Write encrypted files to the output path (clusters/{cluster-name}/ in git).
6. Produce validation report. No cluster connection required.

For pack compilation (triggered as a Kueue Job by ont-infra, not direct invocation):
1. Read PackBuild spec.
2. Pull Helm chart via helm goclient. Render with declared values.
3. Resolve Kustomize overlay via kustomize goclient.
4. Normalize all inputs to flat Kubernetes manifests.
5. Validate all resources against target Kubernetes version schemas.
6. Build execution order from declared dependencies. Fail if acyclic check fails.
7. Generate minimum necessary RBAC.
8. Pin all image references to digest.
9. Compute content-addressed checksum.
10. Generate provenance record with build identity, timestamp, source digests.
11. Push ClusterPack artifact to OCI registry.
12. Write OperationResult with registered ClusterPack version and digest.
13. Exit.

---

## 10. Agent Mode

The runner in agent mode is a long-lived Deployment in ont-system on every cluster.
Same binary, agent startup flag. Implements leader election — only one replica
writes to RunnerConfig status and receipt CRs at a time.

**On startup:**
1. Read RunnerConfig for this cluster.
2. Check license: validate JWT if licenseSecretRef is set. If no JWT and cluster
   count exceeds 5, write LicenseConstraint to RunnerConfig status and exit.
3. Write capability manifest to RunnerConfig status (self-declaration).
4. Start admission webhook server (security plane).
5. Start receipt reconciliation loops (PackReceipt, PermissionSnapshotReceipt).
6. Start drift detection loop for PackReceipt.
7. Start PermissionSnapshot pull loop.

**Every 24 hours:** Re-validate JWT license. Update licenseStatus on RunnerConfig.

**Leader election lease:** Lives in ont-system as a Lease resource named
ont-runner-agent-{cluster-name}. All agent Deployment replicas compete. Only the
leader performs writes.

---

## 11. Enterprise License Enforcement

Community tier: maximum 5 clusters (management counts as 1). No JWT required.
Enterprise tier: JWT license key mounted as Secret, referenced in RunnerConfig
spec.licenseSecretRef.

JWT claims validated by the runner agent: iss (must be ontave.dev), exp (expiry),
maxClusters (licensed cluster count), maxTenants, customerID.

No operator reads or validates the JWT. Operators see only LicenseConstraint
status on RunnerConfig and surface it to their operational CR status. All licensing
intelligence is in the runner binary. Changing the license model requires only a
runner release — no operator changes. This is the enterprise boundary.

---

*runner.ontai.dev schema — ont-runner*
*Amendments appended below with date and rationale.*
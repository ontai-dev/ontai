# ont-runner-schema
> API Group: runner.ontai.dev
> Repository: ont-runner (produces both ont-runner and ont-agent binaries)
> All agents absorb this document. This schema governs both binaries.

---

## 1. Central Principle

The ont-runner repository is the platform intelligence. Operators are thin reconcilers.
All execution logic — compile-time and runtime — lives in the two binaries built from
this repository.

**ont-runner** is the compile-time binary. It is a short-lived tool invoked by humans
or by the bootstrap pipeline. It never runs as a Deployment on any cluster.

**ont-agent** is the runtime binary. It runs as a long-lived Deployment in ont-system
on the management cluster and every target cluster. It also runs as short-lived Kueue
Jobs on the management cluster for all named operational capabilities. It is the only
ONT binary deployed to any cluster. It is distroless.

Human-facing compile operations are invocations of the ont-runner binary in compile
mode. Cluster management operations are performed by submitting ONT CRs which
operators translate into ont-agent Jobs.

---

## 2. Binary Architecture

Both binaries are built from the same Go module at github.com/ontai-dev/ont-runner.
They share pkg/runnerlib and all internal modules except the compile-mode client
wrappers, which are excluded from ont-agent at build time via Go build tags.

**Shared Go clients (both binaries):**
- kube goclient: all Kubernetes API interactions. All modes.

**ont-runner exclusive clients (compile mode only, excluded from ont-agent build):**
- helm goclient: Helm chart rendering. INV-014.
- kustomize goclient: overlay resolution. INV-014.
- SOPS handler: age key encryption of cluster secrets.

**ont-agent exclusive clients (execute and agent modes only):**
- talos goclient: all Talos API interactions. INV-013.
  Pure Go gRPC library. No talosctl binary. No shell invocation.

**No system binary invocations in any mode.** All clients are pure Go library
integrations. No kubectl, no talosctl, no helm binary, no kustomize binary, no
shell invocations at any point in execute or agent mode. Compile mode uses Go
library wrappers only — no shell invocations.

**Three modes — no other modes exist:**

| Mode     | Binary     | Invocation              | Duration    | Image       | Cluster Scope            |
|----------|------------|-------------------------|-------------|-------------|--------------------------|
| compile  | ont-runner | Direct CLI invocation   | Short-lived | Debian      | Never deployed to cluster|
| execute  | ont-agent  | Kueue Job pod           | Short-lived | Distroless  | Management cluster only  |
| agent    | ont-agent  | Deployment in ont-system| Long-lived  | Distroless  | Management + all targets |

Execute mode Jobs run exclusively on the management cluster. Target clusters never
run execute-mode Jobs. All cluster operations reach target clusters remotely via
mounted kubeconfig and talosconfig Secrets.

Mode is determined by startup flag and RunnerConfig mounted at startup for execute
and agent modes. Compile mode reads input paths from CLI flags.

Invoking helm goclient or kustomize goclient in execute or agent mode is a
programming error; the ont-agent binary excludes these clients at build time.
Any attempt causes InvariantViolation and immediate structured exit.

Invoking talos goclient in compile mode is a programming error. INV-013.

---

## 3. Image Tag Convention and Release Pairing

**Stable releases:**
- `registry.ontai.dev/ontai-dev/ont-runner:v{talosVersion}-r{revision}`
- `registry.ontai.dev/ontai-dev/ont-agent:v{talosVersion}-r{revision}`

The talosVersion component declares Talos API compatibility — not cosmetic. A cluster
at Talos v1.9.3 must use an agent tagged v1.9.3-rN. INV-012.

ont-runner and ont-agent always carry the same version tag built from the same source
commit. They are released together. Deploying mismatched versions against the same
cluster is unsupported. INV-024.

**Development:** dev (floating), dev-rc{N} (release candidates). Applied to both images.

**Lab builds:** pushed only to 10.20.0.1:5000/ontai-dev/ont-runner and
10.20.0.1:5000/ontai-dev/ont-agent. Lab tags never appear in the public registry.
INV-011.

Updating RunnerConfig agentImage to the new agent tag is a prerequisite to any Talos
version upgrade. The upgrade reconciler checks this gate before submitting any upgrade
Job.

---

## 4. Shared Runner Library

The shared runner library is owned by the ont-runner repository and imported by all
operators and by both binaries. It is the single source of RunnerConfig schema,
generation logic, and capability manifest structure.

**Library exports:**
- RunnerConfig schema types
- GenerateFromTalosCluster(spec) → RunnerConfig
- GenerateFromPackBuild(spec) → RunnerConfig
- CapabilityManifest types
- OperationResult types
- Job spec builder functions

When a new named capability is added to ont-agent, the shared library is updated.
Operators get the new capability by updating their library dependency version. No
operator logic changes are required for new capabilities.

---

## 5. CRDs

### RunnerConfig

Scope: Namespaced — ont-system (management cluster), tenant-{cluster-name} (targets).
Short name: rc

The live operational contract between operators and ont-agent for a specific cluster
or pack. Operator-generated at runtime using the shared library. Never human-authored.
Never a compile-time artifact.

Key spec fields:
- clusterRef: cluster identity this RunnerConfig governs.
- agentImage: fully qualified ont-agent image including tag. Single source of truth
  for which agent version handles this cluster's Deployments and Jobs. Previously
  named runnerImage — renamed to reflect the two-binary model.
- licenseSecretRef: optional reference to a JWT license Secret. Required for clusters
  beyond the community tier limit (5 target clusters). Management cluster is exempt.
- phases: applicable phases for this cluster (launch, enable for management;
  launch, bootstrap for tenant clusters).
- operationalHistory: append-only record of every configuration change applied.
  Never deleted, only superseded by newer entries for the same concern.

Per-phase parameter sections:
- launch: vmConfig, talosInstallerImage, networkConfig, bootstrapTimeout.
- enable: prerequisiteTimeout, operatorTimeout. Management cluster only.
- bootstrap: agentPackRef, agentNamespace, retryLimit. Tenant clusters only.

Status fields (ont-agent in agent mode populates):
- capabilities: the self-declared capability manifest. List of named capabilities
  the current agentImage supports, each with version and parameter schema.
  Operators read this before submitting Jobs. If capability absent: raise
  CapabilityUnavailable on the operational CR and wait.
- agentVersion: the ont-agent image version currently running as agent.
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

Declares one operator for ont-runner's enable phase to install. Not used for
target cluster operator installation — that is ClusterPack delivery.

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
  by ont-runner — any OperatorManifest with installOrder 1 that is not ont-security
  is a programming error.

Status conditions: Installed, Healthy, Failed.

ont-runner processes OperatorManifests in ascending installOrder sequence. It does
not proceed to the next until the current reaches Healthy. This enforces ont-security
deployment priority and all subsequent dependency ordering.

---

## 6. Named Capabilities

Named capabilities are ont-agent's execution vocabulary in execute mode. Every
operator Job maps to exactly one named capability. New capabilities are added to
ont-agent and declared in the shared library. No operator code changes are required.

**Capability invocation contract:**
The operator stamps the capability name into the Job spec as an environment variable.
ont-agent reads the capability name on startup in execute mode and executes the
corresponding implementation. ont-agent exits with a structured OperationResult.

**Current named capabilities:**

| Capability          | Owner operator  | Triggering CRD                                      | Description                              |
|---------------------|-----------------|-----------------------------------------------------|------------------------------------------|
| bootstrap           | ont-platform    | TalosCluster                                        | Full cluster bootstrap from seed nodes   |
| talos-upgrade       | ont-platform    | TalosUpgrade (capi.enabled=false only)              | CAPI-delegated for target clusters; direct runner Job for management cluster |
| kube-upgrade        | ont-platform    | TalosKubeUpgrade (capi.enabled=false only)          | CAPI-delegated for target clusters; direct runner Job for management cluster |
| stack-upgrade       | ont-platform    | TalosStackUpgrade (capi.enabled=false only)         | CAPI-delegated for target clusters; direct runner Job for management cluster |
| node-patch          | ont-platform    | TalosNodePatch                                      | Machine config patch to nodes            |
| node-scale-up       | ont-platform    | TalosNodeScaleUp (capi.enabled=false only)          | CAPI-delegated for target clusters; direct runner Job for management cluster |
| node-decommission   | ont-platform    | TalosNodeDecommission (capi.enabled=false only)     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| node-reboot         | ont-platform    | TalosReboot (capi.enabled=false only)               | CAPI-delegated for target clusters; direct runner Job for management cluster |
| etcd-backup         | ont-platform    | TalosBackup                                         | etcd snapshot + config export to S3      |
| etcd-maintenance    | ont-platform    | TalosEtcdMaintenance                                | etcd defrag and optional snapshot        |
| etcd-restore        | ont-platform    | TalosRecovery                                       | Disaster recovery from S3 snapshot       |
| pki-rotate          | ont-platform    | TalosPKIRotation                                    | PKI certificate rotation                 |
| credential-rotate   | ont-platform    | TalosCredentialRotation                             | Service account key rotation             |
| hardening-apply     | ont-platform    | TalosHardeningApply                                 | Apply TalosHardeningProfile              |
| cluster-reset       | ont-platform    | TalosClusterReset                                   | Destructive factory reset with human gate|
| pack-compile        | ont-infra       | PackBuild                                           | Compile PackBuild into ClusterPack       |
| pack-deploy         | ont-infra       | PackExecution                                       | Apply ClusterPack to target cluster      |
| rbac-provision      | ont-security    | (agent-initiated)                                   | Provision RBAC artifacts from snapshot   |

Note: talos-upgrade, kube-upgrade, stack-upgrade, node-scale-up, node-decommission,
and node-reboot are confirmed retained. They are not orphaned. The Triggering CRD
for each is active when TalosCluster spec.capi.enabled=false only (management cluster
direct path). For capi.enabled=true clusters CAPI handles these operations natively.

All capabilities run in execute mode on the management cluster as Kueue Jobs using
the distroless ont-agent image. No capability runs on a target cluster as a Job.
All capabilities reach target clusters via mounted kubeconfig and talosconfig Secrets.

**Future-proofing:** When a new named capability is added to ont-agent, it is
declared in the shared library's capability manifest. Operators discover it via
RunnerConfig status. No operator requires changes.

---

## 7. Inter-Job State — Temporary PVC Protocol

For multi-step sequence capabilities (bootstrap, stack-upgrade, cluster-reset),
ont-agent uses a temporary PVC for inter-step state transfer.

Protocol:
1. First Job creates a PVC named ont-{capability}-{cr-name}. Executes step.
   Writes intermediate artifacts to PVC. Updates operational CR status.
2. Subsequent Jobs mount the same PVC. Read previous step outputs. Execute step.
   Write outputs. Update status.
3. Final Job consumes all intermediate artifacts. Creates Kubernetes assets on
   management cluster. Deletes PVC. Writes terminal OperationResult.

The operator never sees the PVC. It only sees CR status advancing. ont-agent
manages PVC lifecycle entirely within the Job sequence. Storage class requirement:
the management cluster must have a storage class available.

---

## 8. OperationResult Protocol

Every execute-mode Job writes an OperationResult JSON document to a ConfigMap before
exit. ConfigMap name derived from Job name. The operator reads it to advance CR status.
No other inter-process communication channel exists between operator and ont-agent.

Structure: phase, status (succeeded or failed), startedAt, completedAt, artifacts
(structured references — never raw content), failureReason (category and detail
when failed), steps (individual step results for multi-step capabilities).

The operator must read OperationResult within the Job's configured TTL. After TTL
expiry the ConfigMap is garbage collected.

---

## 9. Compile Mode (ont-runner binary)

Human invokes: ont-runner compile [cluster|pack] --input <path> --output <path>

For cluster compilation:
1. Read TalosCluster spec and human-provided machineconfig files.
2. Validate TalosCluster spec against ~/ontai/ont-platform-schema.md rules.
3. Validate machineconfig structure against the declared Talos version.
4. SOPS-encrypt talos-secret, machineconfigs, talosconfig using admin's age key.
5. Write encrypted files to the output path (clusters/{cluster-name}/ in git).
6. Produce validation report. No cluster connection required.

For pack compilation (triggered as a Kueue Job by ont-infra using ont-agent image):
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

Note on pack-compile: although Helm and Kustomize are compile-mode clients, pack
compilation runs as a Kueue Job using the ont-agent image. This is possible because
the pack-compile Job invokes the ont-runner binary (mounted as a sidecar volume or
init container) rather than ont-agent's capability engine for the compilation step.
The Job wrapper and OperationResult writing are ont-agent's responsibility. The actual
Helm rendering and Kustomize resolution are delegated to the ont-runner binary invoked
within the Job. This is the only context where ont-runner executes within a Job boundary.

---

## 10. Agent Mode (ont-agent binary)

ont-agent in agent mode is a long-lived Deployment in ont-system on every cluster.
Same binary, agent startup flag. Implements leader election — only one replica
writes to RunnerConfig status and receipt CRs at a time.

**On startup (all clusters):**
1. Read RunnerConfig for this cluster.
2. Validate mode: refuse compile mode flag. INV-023.
3. Check license (management cluster only): validate JWT if licenseSecretRef is set.
   Count target clusters. If count > 5 and no JWT: write LicenseConstraint to
   RunnerConfig status and exit with code 2. Management cluster never counted. INV-025.
4. Write capability manifest to RunnerConfig status (self-declaration).
5. Start receipt reconciliation loops (PackReceipt, PermissionSnapshotReceipt).
6. Start admission webhook server (intercepts RBAC resources).
7. Start local PermissionService gRPC server (serves authorization decisions).
8. Start drift detection loop for PackReceipt.
9. Start PermissionSnapshot pull loop (pulls from management cluster).

**Additional on management cluster agent startup:**
10. Start PackInstance signing loop: watches for new ClusterPack registrations,
    signs PackInstance CRs with the platform signing key.
11. Start PermissionSnapshot signing loop: watches for new PermissionSnapshot
    generation by ont-security, signs them with the platform signing key.

**Signing and verification model:**
The management cluster agent holds the signing key (mounted Secret). It signs
PackInstance and PermissionSnapshot CRs by writing a cryptographic signature
to a dedicated annotation field. Target cluster agents verify this signature
before acknowledging receipt. A signature failure blocks the receipt
acknowledgement and raises DegradedSecurityState. This chain of custody ensures
that target clusters only execute packs and honor permissions that have been
explicitly authorized by the management cluster's security plane.

**Every 24 hours (management cluster only):** Re-validate JWT license.
Update licenseStatus on RunnerConfig.

**Leader election lease:** Lives in ont-system as a Lease resource named
ont-agent-{cluster-name}. All agent Deployment replicas compete. Only the
leader performs writes.

---

## 11. Enterprise License Enforcement

Community tier: maximum 5 target clusters. Management cluster does not count. INV-025.
No JWT required for community tier.

Professional tier: JWT license key. Licensed cluster count as declared.

Enterprise tier: JWT license key mounted as Secret, referenced in RunnerConfig
spec.licenseSecretRef.

JWT claims validated by ont-agent in agent mode on management cluster startup:
iss (must be ontave.dev), exp (expiry), ont_max_clusters (licensed target cluster
count), ont_max_tenants, ont_customer_id, ont_tier, ont_features.

No operator reads or validates the JWT. Operators see only LicenseConstraint
status on RunnerConfig. All licensing intelligence is in ont-agent agent mode.
Changing the license model requires only an ont-agent release — no operator changes.

---

## 12. Dockerfile Standards

**ont-runner Dockerfile (compile mode, debian):**

Build pattern: golang:1.25 builder stage with build tag `-tags runner` compiles the
ont-runner binary with compile-mode clients included. debian:12-slim final stage
includes: bash, curl, jq, python3, openssl, psql, helm binary (for CA bundle
verification during chart pull), kubectl, and the compiled ont-runner binary.
USER 65532:65532. No package manager retained in the final image.

The debian base is required for: /etc/ssl/certs (Helm chart HTTPS pulls), SOPS age
key operations (python3), and psql (CNPG health verification in enable phase).
No other reason for debian exists. This image is never deployed to any cluster.

**ont-agent Dockerfile (execute and agent modes, distroless):**

Build pattern: golang:1.25 builder stage with build tag `-tags agent` compiles the
ont-agent binary. Compile-mode clients (helm goclient, kustomize goclient, SOPS
handler) are excluded at build time. gcr.io/distroless/base:nonroot final stage.
USER 65532:65532. No shell. No package manager. No system tools.

gcr.io/distroless/base (not static) is required because the talos goclient and
gRPC stack require libc for certain TLS and crypto operations. Verify at build time
that the produced binary runs cleanly on the distroless/base image before release.

---

*runner.ontai.dev schema — ont-runner repository*
*Amendments appended below with date and rationale.*

2026-03-30 — Two-binary model adopted. ont-runner confined to compile mode (debian).
  ont-agent owns execute and agent modes (distroless). runnerImage field renamed to
  agentImage on RunnerConfig. Execute mode Jobs confirmed as pure Go — no system
  binaries required. License tier corrected: 5 target clusters community, management
  cluster excluded from count. Signing and verification model added to agent
  responsibilities. CR-INV-009 through CR-INV-010 merged into root CLAUDE.md as
  INV-022 through INV-026.

2026-03-30 — Capability table updated with Triggering CRD column (Path B ruling).
  talos-upgrade, kube-upgrade, stack-upgrade, node-scale-up, node-decommission, and
  node-reboot confirmed retained. Triggering CRDs are active when TalosCluster
  spec.capi.enabled=false only. For capi.enabled=true target clusters CAPI handles
  these operations natively. Orphaned-constant finding closed — these six capability
  constants are not orphaned.
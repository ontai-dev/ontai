# conductor-schema
> API Group: runner.ontai.dev
> Repository: conductor (produces both Compiler and Conductor binaries)
> All agents absorb this document. This schema governs both binaries.

---

## 1. Central Principle

The conductor repository is the platform intelligence. Operators are thin reconcilers.
All execution logic — compile-time and runtime — lives in the two binaries built from
this repository.

**Compiler** is the compile-time binary. It is a short-lived tool invoked by humans
or by the bootstrap pipeline. It never runs as a Deployment on any cluster.

**Conductor** is the runtime binary. It runs as a long-lived Deployment in ont-system
on the management cluster and every target cluster. It also runs as short-lived Kueue
Jobs on the management cluster for all named operational capabilities. It is the only
Seam binary deployed to any cluster. It is distroless.

Human-facing compile operations are invocations of the Compiler binary in compile
mode. Cluster management operations are performed by submitting Seam CRs which
operators translate into Conductor Jobs.

---

## 2. Binary Architecture

Both binaries are built from the same Go module at github.com/ontai-dev/conductor.
They share pkg/runnerlib and all internal modules except the compile-mode client
wrappers, which are excluded from Conductor at build time via Go build tags.

**Shared Go clients (both binaries):**
- kube goclient: all Kubernetes API interactions. All modes.

**Compiler exclusive clients (compile mode only, excluded from Conductor build):**
- helm goclient: Helm chart rendering. INV-014.
- kustomize goclient: overlay resolution. INV-014.
- SOPS handler: age key encryption of cluster secrets.

**Conductor exclusive clients (execute and agent modes only):**
- talos goclient: all Talos API interactions. INV-013.
  Pure Go gRPC library. No talosctl binary. No shell invocation.

**No system binary invocations in any mode.** All clients are pure Go library
integrations. No kubectl, no talosctl, no helm binary, no kustomize binary, no
shell invocations at any point in execute or agent mode. Compile mode uses Go
library wrappers only — no shell invocations.

**Three modes — no other modes exist:**

| Mode     | Binary    | Invocation              | Duration    | Image       | Cluster Scope             |
|----------|-----------|-------------------------|-------------|-------------|---------------------------|
| compile  | Compiler  | Direct CLI invocation   | Short-lived | Debian      | Never deployed to cluster |
| execute  | Conductor | Kueue Job pod           | Short-lived | Distroless  | Management cluster only   |
| agent    | Conductor | Deployment in ont-system| Long-lived  | Distroless  | Management + all targets  |

Execute mode Jobs run exclusively on the management cluster. Target clusters never
run execute-mode Jobs. All cluster operations reach target clusters remotely via
mounted kubeconfig and talosconfig Secrets.

Mode is determined by startup flag and RunnerConfig mounted at startup for execute
and agent modes. Compile mode reads input paths from CLI flags.

Invoking helm goclient or kustomize goclient in execute or agent mode is a
programming error; the Conductor binary excludes these clients at build time.
Any attempt causes InvariantViolation and immediate structured exit.

Invoking talos goclient in compile mode is a programming error. INV-013.

---

## 3. Image Tag Convention and Release Pairing

**Stable releases:**
- `registry.ontai.dev/ontai-dev/compiler:v{talosVersion}-r{revision}`
- `registry.ontai.dev/ontai-dev/conductor:v{talosVersion}-r{revision}`

The talosVersion component declares Talos API compatibility — not cosmetic. A cluster
at Talos v1.9.3 must use a Conductor tagged v1.9.3-rN. INV-012.

Compiler and Conductor always carry the same version tag built from the same source
commit. They are released together. Deploying mismatched versions against the same
cluster is unsupported. INV-024.

**Development:** dev (floating), dev-rc{N} (release candidates). Applied to both images.

**Lab builds:** pushed only to 10.20.0.1:5000/ontai-dev/compiler and
10.20.0.1:5000/ontai-dev/conductor. Lab tags never appear in the public registry.
INV-011.

Updating RunnerConfig agentImage to the new Conductor tag is a prerequisite to any
Talos version upgrade. The upgrade reconciler checks this gate before submitting any
upgrade Job.

---

## 4. Shared Runner Library

The shared runner library is owned by the conductor repository and imported by all
operators and by both binaries. It is the single source of RunnerConfig schema,
generation logic, and capability manifest structure.

**Library exports:**
- RunnerConfig schema types
- GenerateFromTalosCluster(spec) → RunnerConfig
- GenerateFromPackBuild(spec) → RunnerConfig
- CapabilityManifest types
- OperationResult types
- Job spec builder functions

When a new named capability is added to Conductor, the shared library is updated.
Operators get the new capability by updating their library dependency version. No
operator logic changes are required for new capabilities.

---

## 5. CRDs

### RunnerConfig

Scope: Namespaced — ont-system (management cluster), tenant-{cluster-name} (targets).
Short name: rc

The live operational contract between operators and Conductor for a specific cluster
or pack. Operator-generated at runtime using the shared library. Never human-authored.
Never a compile-time artifact.

Key spec fields:
- clusterRef: cluster identity this RunnerConfig governs.
- agentImage: fully qualified Conductor image including tag. Single source of truth
  for which Conductor version handles this cluster's Deployments and Jobs.
- phases: applicable phases for this cluster (launch, enable for management;
  launch, bootstrap for tenant clusters).
- operationalHistory: append-only record of every configuration change applied.
  Never deleted, only superseded by newer entries for the same concern.
- maintenanceTargetNodes: list of node names that are the subject of the operation.
  Populated by the initiating operator at RunnerConfig creation time. Used by
  Conductor execute mode for node affinity exclusion when selfOperation is true.
- operatorLeaderNode: the node currently hosting the leader pod of the initiating
  operator. Resolved at creation time via the Kubernetes downward API. Used by
  Conductor execute mode for node affinity exclusion when selfOperation is true.
- selfOperation: boolean — true when the Job's execution cluster and the target
  cluster are the same (management cluster self-operations). false for all
  tenant-targeted operations. Conductor execute mode reads this field to determine
  whether to apply NotIn node affinity constraints. When false, exclusion logic
  is skipped entirely.

Per-phase parameter sections:
- launch: vmConfig, talosInstallerImage, networkConfig, bootstrapTimeout.
- enable: prerequisiteTimeout, operatorTimeout. Management cluster only.
- bootstrap: agentPackRef, agentNamespace, retryLimit. Tenant clusters only.

Status fields (Conductor in agent mode populates):
- capabilities: the self-declared capability manifest. List of named capabilities
  the current agentImage supports, each with version and parameter schema.
  Operators read this before submitting Jobs. If capability absent: raise
  CapabilityUnavailable on the operational CR and wait.
- agentVersion: the Conductor image version currently running as agent.
- agentLeader: the pod name currently holding the leader election lease.

Status conditions: LaunchComplete, EnableComplete, BootstrapComplete, PhaseFailed,
CapabilityUnavailable.

---

### OperatorManifest

Scope: Namespaced — ont-system. Management cluster only.
Short name: om

Declares one operator for Compiler's enable phase to install. Not used for
target cluster operator installation — that is ClusterPack delivery.

The bootstrap RBACPolicy that is available before Guardian installs must
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
  Prerequisites use order 0. Guardian must always be order 1. This is enforced
  by Compiler — any OperatorManifest with installOrder 1 that is not Guardian
  is a programming error.

Status conditions: Installed, Healthy, Failed.

Compiler processes OperatorManifests in ascending installOrder sequence. It does
not proceed to the next until the current reaches Healthy. This enforces Guardian
deployment priority and all subsequent dependency ordering.

---

## 6. Named Capabilities

Named capabilities are Conductor's execution vocabulary in execute mode. Every
operator Job maps to exactly one named capability. New capabilities are added to
Conductor and declared in the shared library. No operator code changes are required.

**Capability invocation contract:**
The operator stamps the capability name into the Job spec as an environment variable.
Conductor reads the capability name on startup in execute mode and executes the
corresponding implementation. Conductor exits with a structured OperationResult.

**Current named capabilities:**

| Capability          | Owner operator | Triggering CRD                                              | Description                               |
|---------------------|----------------|-------------------------------------------------------------|-------------------------------------------|
| bootstrap           | Platform       | TalosCluster                                                | Full cluster bootstrap from seed nodes    |
| talos-upgrade       | Platform       | UpgradePolicy (capi.enabled=false only)                     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| kube-upgrade        | Platform       | UpgradePolicy (capi.enabled=false only)                     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| stack-upgrade       | Platform       | UpgradePolicy (capi.enabled=false only)                     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| node-patch          | Platform       | NodeMaintenance                                             | Machine config patch to nodes             |
| node-scale-up       | Platform       | NodeOperation (capi.enabled=false only)                     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| node-decommission   | Platform       | NodeOperation (capi.enabled=false only)                     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| node-reboot         | Platform       | NodeOperation (capi.enabled=false only)                     | CAPI-delegated for target clusters; direct runner Job for management cluster |
| etcd-backup         | Platform       | EtcdMaintenance                                             | etcd snapshot + config export to S3       |
| etcd-defrag         | Platform       | EtcdMaintenance                                             | etcd defrag and optional snapshot         |
| etcd-restore        | Platform       | EtcdMaintenance                                             | Disaster recovery from S3 snapshot        |
| pki-rotate          | Platform       | PKIRotation                                                 | PKI certificate rotation                  |
| credential-rotate   | Platform       | NodeMaintenance                                             | Service account key rotation              |
| hardening-apply     | Platform       | NodeMaintenance                                             | Apply HardeningProfile                    |
| cluster-reset       | Platform       | ClusterReset                                                | Destructive factory reset with human gate |
| pack-compile        | Wrapper        | PackBuild spec file (compile mode — not a cluster CRD, not a Kueue Job) | Compiler compile mode: renders PackBuild inputs into ClusterPack OCI artifact |
| pack-deploy         | Wrapper        | PackExecution                                               | Apply ClusterPack to target cluster       |
| rbac-provision      | Guardian       | (agent-initiated)                                           | Provision RBAC artifacts from snapshot    |

Note: talos-upgrade, kube-upgrade, stack-upgrade, node-scale-up, node-decommission,
and node-reboot are confirmed retained. They are not orphaned. The Triggering CRD
for each is UpgradePolicy or NodeOperation, active when TalosCluster
spec.capi.enabled=false only (management cluster direct path). For capi.enabled=true
clusters CAPI handles these operations natively.

All capabilities except pack-compile run in execute mode on the management cluster as
Kueue Jobs using the distroless Conductor image. No capability runs on a target cluster
as a Job. All capabilities reach target clusters via mounted kubeconfig and talosconfig
Secrets.

Note on pack-compile: pack-compile is the sole compile-mode entry in this table. It does
not follow the execute-mode Job pattern that all other capabilities follow. It appears
here for completeness — the capability name constant exists in the shared library so that
Wrapper and Compiler share a common vocabulary. However, pack-compile is never submitted
as a Kueue Job, never run by Conductor, and never runs on any cluster.

**Future-proofing:** When a new named capability is added to Conductor, it is
declared in the shared library's capability manifest. Operators discover it via
RunnerConfig status. No operator requires changes.

---

## 7. Inter-Job State — Temporary PVC Protocol

For multi-step sequence capabilities (bootstrap, stack-upgrade, cluster-reset),
Conductor uses a temporary PVC for inter-step state transfer.

Protocol:
1. First Job creates a PVC named ont-{capability}-{cr-name}. Executes step.
   Writes intermediate artifacts to PVC. Updates operational CR status.
2. Subsequent Jobs mount the same PVC. Read previous step outputs. Execute step.
   Write outputs. Update status.
3. Final Job consumes all intermediate artifacts. Creates Kubernetes assets on
   management cluster. Deletes PVC. Writes terminal OperationResult.

The operator never sees the PVC. It only sees CR status advancing. Conductor
manages PVC lifecycle entirely within the Job sequence. Storage class requirement:
the management cluster must have a storage class available.

---

## 8. OperationResult Protocol

Every execute-mode Job writes an OperationResult JSON document to a ConfigMap before
exit. ConfigMap name derived from Job name. The operator reads it to advance CR status.
No other inter-process communication channel exists between operator and Conductor.

Structure: phase, status (succeeded or failed), startedAt, completedAt, artifacts
(structured references — never raw content), failureReason (category and detail
when failed), steps (individual step results for multi-step capabilities).

The operator must read OperationResult within the Job's configured TTL. After TTL
expiry the ConfigMap is garbage collected.

---

## 9. Compile Mode (Compiler binary)

Human invokes: compiler compile [cluster|pack] --input <path> --output <path>

For cluster compilation:
1. Read TalosCluster spec and human-provided machineconfig files.
2. Validate TalosCluster spec against ~/ontai/platform-schema.md rules.
3. Validate machineconfig structure against the declared Talos version.
4. SOPS-encrypt talos-secret, machineconfigs, talosconfig using admin's age key.
5. Write encrypted files to the output path (clusters/{cluster-name}/ in git).
6. Produce validation report. No cluster connection required.

For pack compilation (Compiler invocation mode — not a Kueue Job, not a cluster
operation):
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

pack-compile is a Compiler compile mode capability. It is invoked by the human or
CI/CD pipeline on the workstation. It never runs on any cluster. It never runs as a
Kueue Job. The ClusterPack OCI artifact and CR YAML it produces are the only outputs
that reach the cluster, via OCI registry and GitOps respectively.

---

## 10. Agent Mode (Conductor binary)

Conductor in agent mode is a long-lived Deployment in ont-system on every cluster.
Same binary, agent startup flag. Implements leader election — only one replica
writes to RunnerConfig status and receipt CRs at a time.

**On startup (all clusters):**
1. Read RunnerConfig for this cluster.
2. Validate mode: refuse compile mode flag. INV-023.
3. Write capability manifest to RunnerConfig status (self-declaration).
4. Start receipt reconciliation loops (PackReceipt, PermissionSnapshotReceipt).
5. Start admission webhook server (intercepts RBAC resources).
6. Start local PermissionService gRPC server (serves authorization decisions).
7. Start drift detection loop for PackReceipt.
8. Start PermissionSnapshot pull loop (pulls from management cluster).

**Additional on management cluster Conductor startup:**
9. Start PackInstance signing loop: watches for new ClusterPack registrations,
   signs PackInstance CRs with the platform signing key.
10. Start PermissionSnapshot signing loop: watches for new PermissionSnapshot
    generation by Guardian, signs them with the platform signing key.

**Signing and verification model:**
The management cluster Conductor holds the signing key (mounted Secret). It signs
PackInstance and PermissionSnapshot CRs by writing a cryptographic signature
to a dedicated annotation field. Target cluster Conductors verify this signature
before acknowledging receipt. A signature failure blocks the receipt
acknowledgement and raises DegradedSecurityState. This chain of custody ensures
that target clusters only execute packs and honor permissions that have been
explicitly authorized by the management cluster's security plane.

**Leader election lease:** Lives in ont-system as a Lease resource named
conductor-{cluster-name}. All Conductor Deployment replicas compete. Only the
leader performs writes.

---

## 11. Licensing

Seam is fully open source with no licensing tier. All clusters are equal. No enforcement.

---

## 12. Operational Readiness Gates

**LOCKED INVARIANT — Platform Governor directive 2026-04-05.**

### Gate 1 — Port 50000 Talos API Reachability

Platform operator is the sole owner of Talos apid port 50000 reachability validation
across both native and CAPI cluster paths. No other operator and no Conductor
capability handler performs port 50000 validation. This is a locked invariant.

**Native clusters (spec.capi.enabled=false):**
The gate is triggered by node IP declaration in TalosCluster spec. When a node IP is
recorded in TalosCluster spec, Platform operator validates reachability to port 50000
before proceeding with any node-level operation.

**CAPI clusters (spec.capi.enabled=true):**
The gate is triggered by CAPI Machine reaching provisioned state. Platform operator
validates port 50000 reachability as part of the SeamInfrastructureMachineReconciler
provisioning sequence. No other reconciler or operator repeats this check.

**Permanent exclusions:**
- Screen (future operator) never performs this check. Screen's responsibility ends at
  infrastructure existence. Port 50000 ownership belongs exclusively to Platform.
- Guardian, Wrapper, Conductor execute mode, and Conductor agent mode never perform
  port 50000 validation under any circumstance.
- Adding port 50000 validation to any component other than Platform operator requires
  a Platform Governor constitutional amendment.

---

## 13. RunnerConfig Self-Operation Contract

**LOCKED INVARIANT — Platform Governor directive 2026-04-05.**

The RunnerConfig spec carries three fields as a first-class scheduling contract. These
fields govern Conductor execute mode node affinity exclusion for management cluster
self-operations. They are populated exclusively by the initiating operator at
RunnerConfig creation time.

**The three fields (defined in Section 5):**
- `maintenanceTargetNodes`: list of node names that are the subject of the operation.
- `operatorLeaderNode`: the node currently hosting the leader pod of the initiating
  operator, resolved via the Kubernetes downward API.
- `selfOperation`: boolean — true when the Job's execution cluster and target cluster
  are the same (management cluster self-operations); false for all tenant-targeted
  operations.

**Operator responsibility at RunnerConfig creation:**
The initiating operator populates all three fields. `operatorLeaderNode` is resolved
at creation time using the Kubernetes downward API (fieldRef: spec.nodeName on the
operator's own pod). The operator must not cache this value — it must be resolved
fresh at each RunnerConfig creation to reflect the current leader pod's node.

**Conductor execute mode contract:**
When selfOperation is true, Conductor translates maintenanceTargetNodes and
operatorLeaderNode into Kueue Job node affinity NotIn constraints before submitting
the Job. This ensures the Job pod does not land on a node that is itself a target
of the maintenance operation, and does not land on the node hosting the operator's
leader pod (which would cause a scheduling deadlock if the node were cordoned).

When selfOperation is false, Conductor skips exclusion resolution entirely. Tenant-
targeted operations are exempt — the Job executes on the management cluster regardless
of which nodes the remote target cluster is operating on.

**Conductor agent mode recovery path:**
Conductor agent mode acts as a recovery path only. It detects Jobs that landed on
maintenance-targeted nodes due to scheduling races (i.e., the NotIn constraint was
applied but a race between admission and cordoning resulted in incorrect placement)
and signals rescheduling by annotating the Job pod. It does not proactively schedule
Jobs. The agent mode recovery path is not a substitute for correct operator-side
field population.

**Permanent exclusions:**
- No other component populates these three fields. They are operator-authored at
  creation time and Conductor-consumed at Job materialisation time.
- Conductor agent mode does not populate these fields. It reads them.
- These fields are never modified after RunnerConfig creation. They are immutable
  for the lifetime of the RunnerConfig instance.

---

## 14. Dockerfile Standards

**Compiler Dockerfile (compile mode, debian):**

Build pattern: golang:1.25 builder stage with build tag `-tags compiler` compiles the
Compiler binary with compile-mode clients included. debian:12-slim final stage
includes: bash, curl, jq, python3, openssl, psql, helm binary (for CA bundle
verification during chart pull), kubectl, and the compiled Compiler binary.
USER 65532:65532. No package manager retained in the final image.

The debian base is required for: /etc/ssl/certs (Helm chart HTTPS pulls), SOPS age
key operations (python3), and psql (CNPG health verification in enable phase).
No other reason for debian exists. This image is never deployed to any cluster.

**Conductor Dockerfile (execute and agent modes, distroless):**

Build pattern: golang:1.25 builder stage with build tag `-tags conductor` compiles the
Conductor binary. Compile-mode clients (helm goclient, kustomize goclient, SOPS
handler) are excluded at build time. gcr.io/distroless/base:nonroot final stage.
USER 65532:65532. No shell. No package manager. No system tools.

gcr.io/distroless/base (not static) is required because the talos goclient and
gRPC stack require libc for certain TLS and crypto operations. Verify at build time
that the produced binary runs cleanly on the distroless/base image before release.

---

*runner.ontai.dev schema — conductor repository*
*Amendments appended below with date and rationale.*

2026-03-30 — Two-binary model adopted. Compiler confined to compile mode (debian).
  Conductor owns execute and agent modes (distroless). runnerImage field renamed to
  agentImage on RunnerConfig. Execute mode Jobs confirmed as pure Go — no system
  binaries required. Signing and verification model added to agent
  responsibilities. CR-INV-009 through CR-INV-010 merged into root CLAUDE.md as
  INV-022 through INV-026.

2026-03-30 — Capability table updated with Triggering CRD column (Path B ruling).
  talos-upgrade, kube-upgrade, stack-upgrade, node-scale-up, node-decommission, and
  node-reboot confirmed retained. Triggering CRDs are active when TalosCluster
  spec.capi.enabled=false only. For capi.enabled=true target clusters CAPI handles
  these operations natively. Orphaned-constant finding closed — these six capability
  constants are not orphaned.

2026-04-03 — Binary rename throughout: conductor → Compiler, conductor → Conductor.
  Repository renamed conductor (was conductor). Module path updated to
  github.com/ontai-dev/conductor. Section 11 Enterprise License Enforcement removed
  entirely — Seam is fully open source with no licensing tier; replaced with single
  sentence. All licensing references removed from RunnerConfig spec and status fields:
  licenseSecretRef removed, licenseStatus removed, LicenseConstraint condition removed.
  Agent startup sequence step 3 (license check) removed; steps renumbered. Section 9
  pack compilation corrected: removed erroneous description of pack-compile as Kueue
  Job triggered by Wrapper; pack-compile is a Compiler invocation mode only.
  Operator name references updated: Platform (formerly platform), Guardian
  (formerly guardian), Wrapper (formerly wrapper). Capability table updated
  to reference consolidated day-two CRDs: UpgradePolicy, NodeOperation,
  EtcdMaintenance, NodeMaintenance, PKIRotation, ClusterReset, HardeningProfile.

2026-04-05 — Two locked Governor directives added. Section 12 "Operational Readiness
  Gates": Platform operator is the sole owner of port 50000 Talos API reachability
  validation across native and CAPI paths; Screen and all other components are
  permanently excluded. Section 13 "RunnerConfig Self-Operation Contract": three new
  first-class scheduling fields added to RunnerConfig spec (maintenanceTargetNodes,
  operatorLeaderNode, selfOperation); Conductor execute mode applies NotIn node
  affinity constraints when selfOperation=true; skips exclusion when selfOperation=false;
  agent mode acts as recovery path only. Dockerfile Standards renumbered to Section 14.

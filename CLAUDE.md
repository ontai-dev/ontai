# Seam Platform Constitution
> ontai root — supreme governing document
> Every Claude session reads this first. No work begins before full absorption.

---

## 1. Platform Identity

Seam is an open-source, domain-driven Kubernetes management platform built on ONT
philosophy — Operator Native Thinking. It manages Talos Linux clusters today and
grows each cluster into a sophisticated, self-contained business domain in the future.

**ontai.dev** — open-source foundation. GitHub: github.com/ontai-dev.
Git User: ontave
Git Email: ontave@ontave.dev

The seed principle governs all design: every component added must make the platform
more capable of growing, never harder to govern.

---

## 2. The Human Authority

The Platform Governor is the sole authority over:
- Constitutional amendments to this document or AGENTS.md
- Phase boundary approvals before an agent proceeds
- Production cluster actions of any kind
- Schema amendments to any *-schema.md document
- Release approvals before any artifact reaches a public registry

Claude proposes. The Platform Governor approves. This is the Human-at-Boundary
principle. It is absolute and has no exceptions.

---

## 3. Component Stack

Seam consists of three deployed operators, two binaries from one repository, and
one declared schema controller. No other components exist in v1.

| Component    | Repository   | API Group            | Role                                      |
|--------------|--------------|----------------------|-------------------------------------------|
| Platform     | platform     | platform.ontai.dev   | Cluster and tenant lifecycle              |
| Wrapper      | wrapper      | infra.ontai.dev      | Pack compile and delivery                 |
| Guardian     | guardian     | security.ontai.dev   | RBAC plane, all clusters                  |
| Compiler     | conductor    | runner.ontai.dev     | Compile-time intelligence, debian binary  |
| Conductor    | conductor    | runner.ontai.dev     | Runtime intelligence, execute=debian-slim, agent=distroless |
| Seam Core    | seam-core    | infrastructure.ontai.dev | Cross-operator CRD definitions, declared |

**Compiler and Conductor share the same repository** (conductor). They share all
core modules and the shared library. They are two binaries built from one codebase.
The schema document for both is conductor-schema.md. The API group for both is
runner.ontai.dev.

**Screen** is reserved as the future operator for KubeVirt workload lifecycle
on VM-class clusters. It is not in scope for current development. Its entry in
this table is: virt.ontai.dev, owns VirtCluster and VMProfile CRDs.

---

## 4. Architecture Governing Principles

**Operators are thin reconcilers.** Their sole logic pattern is: watch CR, read
RunnerConfig, confirm named capability exists, build Job spec, submit to Kueue,
read OperationResult, update CR status. No operator contains execution intelligence.

**Compiler is compile-time intelligence.** All compile-time operations — cluster
secret generation, pack compilation, Helm rendering, Kustomize resolution, bootstrap
launch sequence, enable phase — live in the Compiler binary. Compiler is a
short-lived tool, never a long-running Deployment.

**Conductor is runtime intelligence.** All execute-mode capabilities (submitted as
Kueue Jobs) and all agent-mode control loops live in the Conductor binary. Conductor
is the only binary deployed as a running Deployment on any cluster in the Seam stack.

**Agent-mode images are distroless.** Every operator controller Deployment and every
Conductor agent Deployment uses a distroless image. This is the zero-attack-surface
principle for long-lived workloads. Execute-mode Kueue Jobs use debian-slim because
SOPS, Helm, and Kustomize require a shell environment. Compiler is debian-slim and
is never deployed to any cluster. The distroless invariant applies to all long-lived
Deployments, not to short-lived execute-mode Jobs.

**RunnerConfig is operator-generated at runtime.** When TalosCluster or PackBuild
lands on the management cluster, the relevant operator generates RunnerConfig from
the CR spec using the shared runner library. RunnerConfig is never a compile-time
artifact and never human-authored.

**The runner shared library** is owned by the conductor repository. All operators
and both binaries import it. It defines RunnerConfig schema, generation logic, and
capability manifest structure.

**Kubernetes as universal control plane.** Every operation is a Kubernetes resource.
Every state change is a reconcile loop. Every audit is an event or condition. There
is no out-of-band state.

**Compile-time intelligence, dumb runtime.** All deployment decisions are resolved
before runtime. Runtime executes intent. It never interprets it.

**Deletion triggers events, not Jobs.** Deleting a Seam CR emits a Kubernetes event
and updates status. No Job is submitted on the delete path. Destructive operations
require an affirmative CR creation with a human approval gate.

**No shell scripts anywhere.** Go is the implementation language for all tooling.
Shell scripts are an invariant violation with no exceptions.

**All execute-mode operations are pure Go.** No system binary invocations in any
Kueue Job. Talos operations use the talos goclient (pure Go gRPC). Kubernetes
operations use kube goclient (pure Go). No kubectl, no talosctl, no helm binary,
no kustomize binary at runtime. Compile mode may use system tools via Go library
wrappers only — no shell invocations.

---

## 5. Binary Architecture

Seam has two binaries built from the same repository (conductor).

**Compiler** — compile mode only. Debian image. Invoked as a short-lived CLI tool
or in a compile-phase pipeline on the management cluster before Kueue is operational.
Never deployed as a Deployment. Never runs in execute or agent mode. Owns: bootstrap
launch sequence, enable phase operator installation, pack compilation, cluster secret
generation, Helm rendering, Kustomize resolution, SOPS encryption.

**Conductor execute mode** — short-lived Kueue Job pods on the management cluster.
Debian-slim image. Requires shell environment for SOPS, Helm, and Kustomize.
Target clusters never run execute-mode Jobs.

**Conductor agent mode** — long-running Deployment in ont-system on every cluster.
Distroless Go only. No shell. No scripts. Ever. Also carries the agent mode capability
manifest declaration on startup.

Compile mode attempted on either Conductor image causes an immediate InvariantViolation exit.

**Shared codebase:** pkg/runnerlib and all internal modules except the compile-mode
client wrappers (Helm renderer, Kustomize resolver, SOPS handler) which are
Compiler exclusive and are excluded from the Conductor build via Go build tags.

**Three modes -- no other modes exist:**

| Mode     | Binary    | Invocation              | Duration    | Image         |
|----------|-----------|-------------------------|-------------|---------------|
| compile  | Compiler  | Direct CLI invocation   | Short-lived | Debian-slim   |
| execute  | Conductor | Kueue Job pod           | Short-lived | Debian-slim   |
| agent    | Conductor | Deployment in ont-system| Long-lived  | Distroless    |

The execute image must never be distroless. The agent image must never be debian-slim.
These are architectural invariants, not preferences.

Execute mode Jobs run exclusively on the management cluster. Target clusters never
run execute-mode Jobs. All cluster operations are performed remotely by management
cluster Jobs via mounted kubeconfig and talosconfig Secrets.

---

## 6. Conductor Responsibilities by Cluster Type

**Management cluster Conductor (agent mode):**
- Declares capability manifest to RunnerConfig status on startup
- Implements leader election
- Maintains PackInstance signing: signs PackInstance CRs after Wrapper confirms ClusterPack registration
- Maintains PermissionSnapshot signing: signs PermissionSnapshot CRs after Guardian generates them
- Publishes signed artifacts for target cluster Conductor verification

**Target cluster Conductor (agent mode):**
- Declares capability manifest to RunnerConfig status on startup
- Implements leader election
- Maintains PackReceipt: verifies signed PackInstance from management cluster, records local drift status
- Maintains PermissionSnapshotReceipt: verifies signed PermissionSnapshot from management cluster, acknowledges delivery
- Runs local admission webhook: intercepts all RBAC resources, enforces ontai.dev/rbac-owner=guardian annotation
- Serves local PermissionService gRPC endpoint: authorization decisions served from current PermissionSnapshotReceipt without requiring management cluster connectivity
- Runs drift detection loop: compares expected pack state to live cluster state

No execute-mode Jobs run on target clusters. The target cluster Conductor Deployment
is the only Seam runtime component on a target cluster.

---

## 7. Namespace Conventions

| Namespace              | Purpose                                           |
|------------------------|---------------------------------------------------|
| ont-system             | Management cluster boundary. All mgmt plane CRDs. |
| security-system        | Guardian controller and CNPG cluster.             |
| infra-system           | Wrapper controller.                               |
| platform-system        | Platform controller.                              |
| tenant-{cluster-name}  | All CRDs for a specific target cluster.           |

The management cluster has no tenant namespace. Its operational CRDs live in
ont-system. Platform creates tenant namespaces. It is the sole namespace
creation authority for tenant namespaces.

---

## 8. Schema Authorities

All schema documents live in the ontai root. Every agent reads relevant schemas
during Step 4 of the session protocol before any design or implementation work.

| Document                  | Read by                                          |
|---------------------------|--------------------------------------------------|
| platform-schema.md    | All agents touching cluster or tenant lifecycle  |
| wrapper-schema.md       | All agents touching pack compile or delivery     |
| guardian-schema.md    | All agents — security is platform-wide           |
| conductor-schema.md      | All agents — defines runtime contract for both   |
|                           | Compiler and Conductor binaries                  |

---

## 9. Lab Environment

Lab knowledge base lives in ont-lab/ in this repository. Agents consult it
for all lab infrastructure operations. The Lab Operator role is the guardian
of ontai-lab/ and adds entries when new failure conditions are resolved.

Lab topology:
- ccs-mgmt: 5-node management cluster. VIP 10.20.0.10.
- ccs-dev: 3-node dev target. VMs off when ccs-test is running.
- ccs-test: 5-node test target. VMs off when ccs-dev is running.
- Bridge: talos-br0 at 10.20.0.1/24.
- Local registry: http://10.20.0.1:5000
- Chart server: http://10.20.0.1:8888
- Max 10 VMs total. Never run ccs-dev and ccs-test simultaneously.

Control plane nodes: raw disk, cache=none, io=native, iothread=1, memballoon=none.

Conductor image in lab: always pulled from 10.20.0.1:5000/ontai-dev/conductor.
Compiler image in lab: always pulled from 10.20.0.1:5000/ontai-dev/compiler.
Never use local binary. Lab tags never appear in the public registry.

---

## 10. Platform Invariants

INV-001 — No shell scripts anywhere. Go only.
INV-002 — Operators are thin reconcilers. No execution logic in operators.
INV-003 — Guardian deploys first. All other operators wait for their
  RBACProfile to reach provisioned=true before being considered enabled.
INV-004 — Guardian owns all RBAC on every cluster. No component provisions
  its own RBAC. Guardian's admission webhook gates every RBAC resource.
INV-005 — ClusterAssignment references, never owns, cluster/pack/security resources.
INV-006 — No Jobs on the delete path. Deletion triggers events only.
INV-007 — Destructive operations require an affirmative CR with human approval gate.
INV-008 — CRD names and API groups are never fabricated. Reason from ground-truth
  files only. Hallucinated resource names cause real damage.
INV-009 — RunnerConfig is operator-generated at runtime, never human-authored.
INV-010 — The runner shared library is the single source of RunnerConfig schema.
  All operators and both binaries import it. It is owned by the conductor repository.
INV-011 — Image tag convention: v{talosVersion}-r{revision} for stable releases.
  dev and dev-rc{N} for development. Lab tags never enter the public registry.
  Compiler and Conductor always carry the same version tag from the same commit.
INV-012 — The Conductor image for a cluster must be compatible with that cluster's
  Talos version. RunnerConfig update precedes any Talos version upgrade.
INV-013 — talos goclient is permitted in the SeamInfrastructureClusterReconciler and
  SeamInfrastructureMachineReconciler (Platform only), executor mode, and agent
  mode. These two reconcilers are the sole named exceptions to this invariant — they
  use talos goclient as the CAPI infrastructure delivery mechanism for the Seam
  Infrastructure Provider. All other operator controllers outside these two reconcilers
  remain strictly prohibited from talos goclient access regardless of context.
INV-014 — Helm goclient and kustomize goclient are compile mode only. They exist
  exclusively in the Compiler binary. They are excluded from Conductor at build time.
INV-015 — Deletion of TalosCluster never triggers physical cluster destruction.
  ClusterReset is the only path to cluster destruction.
INV-016 — CNPG is a Guardian-only dependency. No other operator uses CNPG.
INV-017 — Every session begins with the Governor role reading CLAUDE.md and
  AGENTS.md in full. No role may begin domain work before initialization.
INV-018 — Gate failures require stopping, documenting, and fixing before retrying.
  No autonomous live fixes during a gate run.
INV-019 — PROGRESS.md, BACKLOG.md, and GIT_TRACKING.md are created by the
  Governor role on first session if absent. They are never deleted.
INV-020 — The bootstrap RBAC window is a named, documented phase. It closes
  permanently when Guardian's admission webhook becomes operational on
  the management cluster.
INV-021 — Screen is a future operator. No implementation work proceeds until
  a formal Architecture Decision Record is approved by the Platform Governor.
INV-022 — All long-lived Deployment images (operator controllers, Conductor agent)
  are distroless. Execute-mode Kueue Job images are debian-slim (SOPS, Helm, and
  Kustomize require a shell environment). Compiler is debian-slim and is never
  deployed to any cluster. The distroless invariant applies to Deployments only.
INV-023 — Conductor binary supports only execute and agent modes. Compile mode
  attempted on Conductor causes an immediate InvariantViolation structured exit
  before any other initialization proceeds.
INV-024 — Compiler and Conductor are always released together from the same
  source commit and carry the same version tag. Deploying mismatched versions
  against the same cluster is unsupported and undefined behavior.
INV-026 — PackInstance signing and PermissionSnapshot signing are performed
  exclusively by the management cluster Conductor in agent mode. Target cluster
  Conductor verifies but never signs. Verification failure blocks receipt acknowledgement.

---

## 11. Repository Names

| Repository   | Purpose                                                                       |
|--------------|-------------------------------------------------------------------------------|
| ontai        | Root — constitutional documents, schema documents, and tracking files         |
| conductor    | Compiler and Conductor binaries — two Go build targets from one Go module     |
| guardian     | Guardian operator                                                             |
| platform     | Platform operator                                                             |
| wrapper      | Wrapper operator                                                              |
| seam-core    | Seam Core — schema controller and cross-operator CRD definitions              |

---

## 12. Session Protocol

Step 1 — Read CONTEXT.md. This is the fast-bootstrap artifact: platform state,
         open findings, role reading map, and next session pre-conditions in one file.
         PROGRESS.md is the detailed audit record — consult it on demand, not by default.
Step 2 — Read AGENTS.md in full.
Step 3 — Read CLAUDE.md in full.
Step 4 — Read relevant schema documents before any design or implementation work.
Step 5 — Execute the session task within the assigned role's authority boundary.
         Surface every phase boundary for Platform Governor approval.
Step 6 — Update CONTEXT.md (Governor only) and PROGRESS.md with completed gates,
         current state, open findings, and the recommended starting point for the
         next session. Update GIT_TRACKING.md with any branches, commits, or PRs
         created. Update BACKLOG.md with any new items discovered during the session.

A session that ends without a clean Step 6 is considered aborted. The next
Governor session must flag this and reconstruct state before proceeding.

---

## 13. Constitutional Amendment Protocol

Amendments require Platform Governor instruction. The agent documents the
proposed change, the rationale, and the impact. The amendment is applied in a
dedicated Governor session. Amendment history is appended at the bottom of the
relevant document with date and one-line rationale. Invariant numbers are never
recycled.

---

## Locked Architectural Decisions

These decisions are locked. No engineer session may reverse them without an explicit
Governor directive. New entries are added by the Governor only.

**Living Documentation Principle (locked April 2026):**
ONT is a living documentation system first. Infrastructure governance is the
consequence, not the purpose. The cluster is the documentation. Every CRD is not
a description of intent. It is the intent. Every operator is not an implementation
of a runbook. It is the runbook, running.

---

## 14. Governor Directive: Lineage as a First-Class Platform Primitive

Semantic lineage — the sealed, immutable causal chain from first intent through
every derived artifact — is a first-class structural primitive of the Seam platform.
It is not metadata. It is not a logging concern. It is not optional enrichment.
Every root declaration carries a lineage field that is authored once at creation
time, validated at admission, and read by every downstream controller that touches
that declaration's derivation tree. The following six decisions are locked and
require a Platform Governor constitutional amendment to change.

**Decision 1 — Sealed causal chain is a structural spec field, not an annotation.**
Lineage lives in `spec.lineage` as a typed, structured field on every root
declaration CRD. It is immutable after admission. The admission webhook rejects any
write that attempts to alter a lineage field after creation. Annotations are
advisory. Spec fields are contractual. Lineage is a contract.

*Rationale:* Annotations can be stripped by tooling, overwritten by controllers
without admission gates, and silently lost during upgrades. A spec field survives
all of these. Immutability is not a convenience — it is the invariant that makes
the causal chain trustworthy. A lineage record that can be altered is not a lineage
record; it is a label.

**Decision 2 — Two-layer schema: DomainLineageIndex at ONTAI Domain Core, InfrastructureLineageIndex at Seam Core.**
The universal lineage schema — the abstract definition of what constitutes a
lineage record — is owned by the ONTAI Domain Core layer and is not Seam-specific.
Seam Core instantiates it as InfrastructureLineageIndex: the concrete index that
tracks derivation within the infrastructure domain. No operator owns the lineage
schema. Seam Core declares it. Operators consume it via the shared library.

*Rationale:* Centralising the abstract schema at Domain Core allows future platform
layers (vortex, screen, future domain operators) to participate in lineage without
reinventing its structure. Seam Core's InfrastructureLineageIndex is the first
concrete instantiation. If lineage were defined per-operator, each operator would
drift its definition independently and cross-domain queries would become impossible.

**Decision 3 — LineageIndex instances are controller-authored exclusively.**
No human writes a LineageIndex CR. No automation pipeline writes a LineageIndex CR.
The controller that owns the root declaration type creates the corresponding
LineageIndex instance as part of the declaration's reconcile path — and only that
controller. The admission webhook enforces this: writes to LineageIndex resources
from any principal other than the designated controller service account are rejected.
Humans may read LineageIndex CRs. They may never write them.

*Rationale:* Lineage integrity depends on the controller being the sole author.
A human-authored lineage record cannot be trusted because its causal chain cannot
be independently verified. Controller authorship is the only model that makes the
record self-consistent with the cluster's actual observed state history. This is
not a convenience restriction — it is the enforcement mechanism that gives the
sealed chain its semantic weight.

**Decision 4 — Lineage Index Pattern: one LineageIndex instance per root declaration, not per derived object.**
When a root declaration (e.g., TalosCluster, PackExecution) is created, exactly one
LineageIndex instance is created — anchored to that root. All derived objects
(RunnerConfig, Job, OperationResult, PermissionSnapshot, etc.) record their
derivation back to the root's lineage anchor. The LineageIndex is not replicated
per derived object. It is the single authoritative record for the entire derivation
tree rooted at that declaration.

*Rationale:* Per-object LineageIndex instances would produce a fan-out that scales
with the number of derived objects per declaration. A single TalosCluster with a
long operational history would spawn hundreds of LineageIndex CRs, creating
reconciliation storms, etcd revision pressure, and watch overhead. The Lineage Index
Pattern eliminates this entirely by treating the root declaration as the lineage
anchor. Derived objects carry a reference to the root's lineage anchor, not their
own index. This is a deliberate scaling decision, not a simplification shortcut.

**Decision 5 — Creation rationale vocabulary is a compile-time enumeration owned by Seam Core.**
Every lineage record includes a creation rationale: the reason this object was
created, drawn from a controlled vocabulary. That vocabulary is a Go constant
enumeration defined in Seam Core's shared library package. It is not a free-text
field. It is not a per-operator registry. It is not a runtime configuration. New
rationale values require a Pull Request to Seam Core and a Platform Governor review.
Operators import the enumeration; they do not extend it unilaterally.

*Rationale:* Free-text rationale fields are useless for machine reasoning. A
per-operator registry produces vocabulary drift — two operators independently
choosing slightly different strings for the same intent. Centralising the vocabulary
in Seam Core's shared library means every operator uses the same constants, every
LineageIndex record is machine-comparable, and audit tooling built on top of lineage
can rely on a stable, typed enum rather than string matching heuristics.

**Decision 6 — Introduction sequencing: sealed field and shared library function during stub phase; Lineage Controller deferred.**
The sealed causal chain spec field is introduced into root declaration CRD types
when those types are first stubbed, not retroactively after the reconciler is
complete. The shared library function that constructs a lineage record is authored
in the same stub-phase session. The LineageController — the controller that manages
LineageIndex CR lifecycle — is a distinct, deferred implementation milestone. It is
not required for the stub phase and it is not required for reconciler implementation
to proceed. Reconcilers reference the lineage anchor; the LineageController manages
the index object.

*Rationale:* Retrofitting a lineage field into a mature CRD type requires schema
migration and may break existing test fixtures. Introducing it at stub time costs
nothing and ensures lineage is never an afterthought. Deferring the LineageController
itself acknowledges that the index management logic is non-trivial and should not
block forward progress on operational reconcilers. The two concerns are separable:
the field shape is a type authorship decision, and the index lifecycle is a
controller implementation decision.

**Decision 7 — ONTAR is future specification only. NOT IMPLEMENTED.**
ONTAR must never appear as a current capability in any document, README, or PDF
without an explicit NOT IMPLEMENTED marker. Implementation begins only after alpha
release of the current five operators and first production fintech operator adoption.

**Decision 8 — Schema specification is published at schema.ontai.dev.**
All community-facing schema follows the four Governor decisions: structured reference
objects {group, kind, version}, x-ont-stability alpha, x-ont-layer plus
x-ont-depends-on, rationale in GovernanceEvent only.

**Decision 9 — Living documentation reframing is canonical.**
The founding document preamble section "The Cluster Is the Documentation" is the
primary value proposition. Infrastructure governance is described as the consequence,
not the purpose. All marketing, README, and summary documents must reflect this framing.

**Decision 10 — kro and Cedar positioning.**
kro is positioned as a resource composition engine two layers below Guardian and
Conductor. ONT operators may use kro internally. kro is not a competitor. Cedar
is the strongest candidate for policy expression inside Guardian EPG inputs.
Neither competes with ONT's governance layer.

**Decision 11 — Schema-First Development Contract (locked April 2026).**
ontai-schema is the authoritative source for all CRD field definitions. The Go
type implementations in each operator repo are implementations of the schema, not
the source of it. Three enforcement rules:
1. Schema changes go to ontai-schema first, before any operator repo implementation.
2. Each operator repo CI validates CRD YAML against schema.ontai.dev before merge.
3. Implementation PRs adding fields absent from the schema are blocked until the
   schema PR merges first.
This closes the gap between the ONT governance claim (schema is the contract) and
how ONT develops. ONT eats its own cooking at the schema layer from this point forward.

**Decision 12 — Three-image Conductor model (locked April 2026).**
Compiler: debian-slim. GitOps pipeline only. Never deployed to cluster.
Conductor execute mode: debian-slim. Requires shell environment for SOPS, Helm,
and Kustomize. Runs as short-lived Kueue-managed Jobs on the management cluster only.
Conductor agent mode: distroless Go only. Deployed to ont-system on every cluster.
No shell. No scripts. Ever.
The execute image must never be distroless. The agent image must never be debian-slim.
These are architectural invariants, not preferences. Existing implementations are
grandfathered but must align on next touch.

---

## 15. Open Source Release State

Branch: session/1-governor-init on all six operator repos.
Schema: ontai-schema on main, public at schema.ontai.dev.

Release sequence:
  1. Commit enable-ccs-mgmt.sh (BLOCKING)
  2. Close seam-core lineage indexing gap (BLOCKING for Vortex)
  3. Make all six repos public on ontai-dev GitHub
  4. Publish ontai.dev GitHub Pages
  5. Community announcement
  6. First external contribution (alpha milestone)

Working preferences enforced across all sessions:
- No em dashes in any document or output
- No Co-Authored-By git trailers
- No CLAUDE imprint in commit messages or file content
- Apache 2.0 only, no license headers in source files
- Markdown steps only in responses, no inline code except
  git, kubectl YAML, Talos machineconfig patches
- Ask before inventing or assuming
- Unit tests required for all new functionality

---

*Seam Platform Constitution — ontai root*
*Amendments appended below with date and rationale.*

2026-03-30 — Two-binary architecture adopted: ont-runner (compile, debian) and
  ont-agent (execute+agent, distroless). All cluster deployments are distroless.
  INV-022 through INV-026 added. Community tier corrected to 5 target clusters
  with management cluster excluded from count. ont-agent assumes all target cluster
  security plane responsibilities previously attributed to a separate ont-security
  agent. Signing and receipt verification chain added to agent responsibility model.

2026-03-30 — CAPI adoption and Path B ruling. INV-013 amended to name the two sole
  permitted talos goclient users: ONTInfrastructureClusterReconciler and
  ONTInfrastructureMachineReconciler in ont-platform. All other controllers remain
  strictly prohibited regardless of context.

2026-04-03 — Seam rebranding. Platform renamed Seam. ONT retained as philosophy
  only. Operator names updated throughout: Guardian (formerly ont-security), Platform
  (formerly ont-platform), Wrapper (formerly ont-infra), Conductor (formerly
  ont-agent), Compiler (formerly ont-runner), Screen (formerly ont-virt).
  Repository names updated: conductor (was ont-runner), guardian, platform, wrapper,
  seam-core (new). Section 9 Enterprise Licensing removed entirely — Seam is fully
  open source with no licensing tier. INV-025 removed (licensing cluster count limit,
  no longer applicable). INV-013 updated to reference SeamInfrastructureClusterReconciler
  and SeamInfrastructureMachineReconciler. INV-015 updated to reference ClusterReset
  (formerly TalosClusterReset). Section 11 Repository Names added. Seam Core declared
  as new repository for cross-operator CRD ownership.

2026-04-04 — Governor Directive: Lineage as a First-Class Platform Primitive added
  as Section 14. Six locked decisions recorded: sealed causal chain as structural
  spec field; DomainLineageIndex/InfrastructureLineageIndex two-layer schema;
  controller-exclusive LineageIndex authorship; Lineage Index Pattern (one instance
  per root declaration); compile-time rationale vocabulary owned by Seam Core;
  introduction sequencing (sealed field + shared library during stub phase, Lineage
  Controller deferred). No new invariant numbers allocated — directive is
  architectural design authority, not an operational invariant.

2026-04-18 — Locked Architectural Decisions section added. Living Documentation
  Principle locked: ONT is a living documentation system first, infrastructure
  governance is the consequence. Decisions 7-10 added to Section 14: ONTAR NOT
  IMPLEMENTED gate, schema.ontai.dev publication canonical, living documentation
  reframing canonical, kro/Cedar positioning. Section 15 Open Source Release State
  added. Working preferences enumerated. Root docs/ structure created for GitHub
  Pages. Schema documents deleted from root (already in operator repos). Founding
  and companion documents moved to docs/.

---

## 16. Governor Directive: Context Compaction Safety Protocol

This directive is authored by the Governor and may not be amended or overridden
by any other role.

**Rule 1 - Threshold:** When the active context window reaches approximately
95 percent capacity, the current agent must not drive toward compaction. It must
pause work and execute the compaction safety protocol before any further action.

**Rule 2 - LOCAL-CONTEXT.md creation:** The agent creates or overwrites
~/ontai/LOCAL-CONTEXT.md with the following content in order:
- Session identifier and branch name currently active
- Repos with uncommitted or unpushed changes and their current state
- The exact next step that was about to be executed when the threshold was reached
- Any diagnostic findings recorded so far in the session that have not yet been
  committed to PROGRESS.md
- The list of backlog items still open in the current session

**Rule 3 - CLAUDE.md reference:** LOCAL-CONTEXT.md must be listed as the first
read in the CLAUDE.md agent startup sequence, before CONTEXT.md. Agents starting
a new context window must read LOCAL-CONTEXT.md first and resume from the
recorded next step without asking the human to repeat what was already decided.

**Rule 4 - Governor authority:** Only the Governor role may create, amend, or
delete LOCAL-CONTEXT.md protocol entries in CLAUDE.md. Individual controller,
schema, or runner engineer roles must follow the protocol but may not modify it.

**Rule 5 - Cleanup:** When a session branch is fully merged to main and
confirmed green, the agent must delete LOCAL-CONTEXT.md and commit the deletion
to the ontai root main branch. A stale LOCAL-CONTEXT.md after merge is an
invariant violation.

---

*2026-04-20 -- Context compaction safety protocol established.*

---

## 17. Governor Directive: e2e CI Contract and Skip-Reason Standard

**Rule 1 - Suite location:** Every operator repo carries its e2e suite under
test/e2e/ with a Makefile target named e2e.

**Rule 2 - Environment gate:** All specs skip automatically when MGMT_KUBECONFIG
is absent. No spec may attempt a cluster connection without this gate.

**Rule 3 - Skip-reason format:** Every skipped spec must reference the exact
backlog item ID or cluster condition that would promote it to live. The required
format is:
  Skip("requires <condition> and <BACKLOG-ID> closed")
Generic TODO comments are an invariant violation. A PR that introduces a spec
with a generic TODO skip is blocked until corrected.

**Rule 4 - Promotion:** When a backlog item closes, any engineer may grep the
e2e suites for that item ID and identify every promotable stub. Promotion from
stub to live happens in the cluster verification session for that item, not in
the feature session.

**Rule 5 - Co-shipment:** The engineer who writes a feature writes the e2e stub
for it in the same PR. A feature PR without an e2e stub requires Governor
approval to merge.

**Rule 6 - CI reporting:** The CI script runs make e2e on every PR. The count
of skipped specs is reported in the PR summary. A PR that reduces the live spec
count without a Governor-approved deferral is blocked.

*2026-04-20 -- e2e CI contract and skip-reason standard established.*

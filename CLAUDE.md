# Seam Platform Constitution
> ontai root -- supreme governing document. Read before beginning any work.
> Git user: ontave / ontave@ontave.dev / github.com/ontai-dev

---

## 1. Platform Identity

Seam: open-source, domain-driven Kubernetes management platform on ONT philosophy.
Seed principle: every component added must make the platform more capable of growing, never harder to govern.

| Component   | Repository  | API Group                              | Role                                                     |
|-------------|-------------|----------------------------------------|----------------------------------------------------------|
| Platform    | platform    | platform.ontai.dev (operational CRDs)  | Cluster and tenant lifecycle                             |
| Wrapper     | wrapper     | infrastructure.ontai.dev (via seam-core) | Pack compile and delivery                              |
| Guardian    | guardian    | security.ontai.dev                     | RBAC plane, all clusters                                 |
| Compiler    | conductor   | infrastructure.ontai.dev (via seam-core) | Compile-time intelligence, debian-slim                 |
| Conductor   | conductor   | infrastructure.ontai.dev (via seam-core) | Runtime intelligence, execute=debian-slim agent=distroless |
| Seam Core   | seam-core   | infrastructure.ontai.dev               | All cross-operator CRD definitions (Decision G)          |
| Domain Core | domain-core | core.ontai.dev                         | Domain primitive declarations, no controller             |

Screen: reserved. virt.ontai.dev. No implementation until Governor-approved ADR (INV-021).

---

## 2. Human Authority

Governor is sole authority over: constitutional amendments, AGENTS.md amendments, phase boundary approvals, production cluster actions, schema amendments to any schema document, release approvals.
Claude proposes. The Platform Governor approves. Human-at-Boundary principle. Absolute. No exceptions.

---

## 3. Session Protocol

Step 1 -- If LOCAL-CONTEXT.md exists, read it first and resume from the recorded next step. Otherwise read CONTEXT.md.
Step 2 -- Read AGENTS.md in full.
Step 3 -- Read CLAUDE.md in full.
Step 4 -- Read the in-scope repo CLAUDE.md for repo-specific constraints. Read schema documents from docs/ in each operator repo before any design or implementation work. Read CODEBASE.md in the root and in the target repo before any implementation or investigation.
Step 5 -- Execute within assigned role authority. Surface every phase boundary for Governor approval.
Step 6 -- Update CONTEXT.md (Governor only), PROGRESS.md, GIT_TRACKING.md, BACKLOG.md at session close.
A session without Step 6 is aborted. The next Governor session must reconstruct state before proceeding.

---

## 4. Working Preferences

- No em dashes in any document or output
- No Co-Authored-By git trailers
- No CLAUDE imprint in commit messages or file content
- Apache 2.0 only, no license headers in source files
- Markdown steps only in responses, no inline code except git, kubectl YAML, Talos machineconfig patches
- Ask before inventing or assuming
- Unit tests required for all new functionality
- **After every implementation or feature change**: Update the CODEBASE.md in any repo you modified. If cross-repo relationships changed, update the parent CODEBASE.md. This is not optional.

---

## 5. Cross-Cutting Invariants

INV-001 -- No shell scripts anywhere. Go only.
INV-002 -- Operators are thin reconcilers. No execution logic in operators.
INV-003 -- Guardian deploys first. All operators wait for RBACProfile provisioned=true before being considered enabled.
INV-004 -- Guardian owns all RBAC on every cluster. No component provisions its own RBAC. Guardian's admission webhook gates every RBAC resource.
INV-006 -- No Jobs on the delete path. Deletion triggers events only.
INV-007 -- Destructive operations require an affirmative CR with human approval gate.
INV-008 -- CRD names and API groups are never fabricated. Reason from ground-truth files only. Hallucinated resource names cause real damage.
INV-009 -- RunnerConfig is operator-generated at runtime, never human-authored.
INV-010 -- seam-core is the single source of RunnerConfig and all cross-operator CRD type definitions (Decision G). The conductor shared library (pkg/runnerlib) provides generation logic and job-spec builders that import seam-core types; it is not the schema authority. All operators and both binaries import seam-core types via the Go module dependency.
INV-011 -- Image tag convention: v{talosVersion}-r{revision} stable, dev/dev-rc{N} development. Lab tags never enter the public registry. Compiler and Conductor carry the same tag from the same commit.
INV-012 -- Conductor image for a cluster must be compatible with that cluster's Talos version. RunnerConfig update precedes any Talos version upgrade.
INV-013 -- talos goclient is permitted in SeamInfrastructureClusterReconciler and SeamInfrastructureMachineReconciler (Platform only), executor mode, and agent mode. These two reconcilers are the sole named exceptions. All other operator controllers are strictly prohibited from talos goclient access regardless of context.
INV-016 -- CNPG is a Guardian-only dependency. No other operator uses CNPG.
INV-017 -- Every session reads CLAUDE.md and AGENTS.md in full before domain work begins.
INV-018 -- Gate failures require stopping, documenting, and fixing before retrying. No autonomous live fixes during a gate run.
INV-019 -- PROGRESS.md, BACKLOG.md, and GIT_TRACKING.md are created by the Governor on first session if absent. They are never deleted.
INV-020 -- The bootstrap RBAC window is a named, documented phase. It closes permanently when Guardian's admission webhook becomes operational on the management cluster.
INV-021 -- Screen is a future operator. No implementation until Governor-approved ADR.
INV-022 -- Long-lived Deployment images (operator controllers, Conductor agent) are distroless. Execute-mode Kueue Job images are debian-slim. Compiler is debian-slim, never deployed to cluster.
INV-023 -- Operator Deployments and enable bundles always reference the `:dev` image tag in lab/development environments. Custom per-build tags (e.g., `dev-r86f75ab`, `dev-rff55d9a`) are never written into Deployment YAML, enable bundles, or any committed artifact. The `:dev` tag is the single moving pointer for all local lab deploys. Stable release tags follow the v{talosVersion}-r{revision} convention (INV-011).

---

## 6. Locked Architectural Decisions

No engineer session may reverse these without an explicit Governor directive. Amendments require Platform Governor instruction in a dedicated session. Invariant numbers are never recycled. New entries by Governor only.

**Living Documentation Principle (locked April 2026):**
ONT is a living documentation system first. Infrastructure governance is the consequence, not the purpose. The cluster is the documentation. Every CRD is not a description of intent. It is the intent. Every operator is not an implementation of a runbook. It is the runbook, running.

**Decision 1 -- Sealed causal chain is a structural spec field, not an annotation.**
Lineage lives in `spec.lineage` as a typed, structured field on every root declaration CRD. It is immutable after admission. The admission webhook rejects any write that attempts to alter a lineage field after creation. Annotations are advisory. Spec fields are contractual. Lineage is a contract.

**Decision 2 -- Two-layer schema: DomainLineageIndex at ONTAI Domain Core, InfrastructureLineageIndex at Seam Core.**
The universal lineage schema is owned by the ONTAI Domain Core layer and is not Seam-specific. Seam Core instantiates it as InfrastructureLineageIndex: the concrete index that tracks derivation within the infrastructure domain. No operator owns the lineage schema. Seam Core declares it. Operators consume it via the shared library.

**Decision 3 -- LineageIndex instances are controller-authored exclusively.**
No human writes a LineageIndex CR. No automation pipeline writes a LineageIndex CR. The controller that owns the root declaration type creates the corresponding LineageIndex instance as part of the declaration's reconcile path, and only that controller. The admission webhook enforces this: writes to LineageIndex resources from any principal other than the designated controller service account are rejected. Humans may read LineageIndex CRs. They may never write them.

**Decision 4 -- Lineage Index Pattern: one LineageIndex instance per root declaration, not per derived object.**
When a root declaration (e.g., TalosCluster, PackExecution) is created, exactly one LineageIndex instance is created, anchored to that root. All derived objects (RunnerConfig, Job, OperationResult, PermissionSnapshot, etc.) record their derivation back to the root's lineage anchor. The LineageIndex is not replicated per derived object. It is the single authoritative record for the entire derivation tree rooted at that declaration.

**Decision 5 -- Creation rationale vocabulary is a compile-time enumeration owned by Seam Core.**
Every lineage record includes a creation rationale drawn from a controlled vocabulary. That vocabulary is a Go constant enumeration defined in Seam Core's shared library package. It is not a free-text field. It is not a per-operator registry. It is not a runtime configuration. New rationale values require a Pull Request to Seam Core and a Platform Governor review. Operators import the enumeration; they do not extend it unilaterally.

**Decision 6 -- Introduction sequencing: sealed field and shared library function during stub phase; Lineage Controller deferred.**
The sealed causal chain spec field is introduced into root declaration CRD types when those types are first stubbed, not retroactively after the reconciler is complete. The shared library function that constructs a lineage record is authored in the same stub-phase session. The LineageController -- the controller that manages LineageIndex CR lifecycle -- is a distinct, deferred implementation milestone. It is not required for the stub phase and it is not required for reconciler implementation to proceed. Reconcilers reference the lineage anchor; the LineageController manages the index object.

**Decision 7 -- ONTAR is future specification only. NOT IMPLEMENTED.**
ONTAR must never appear as a current capability in any document, README, or PDF without an explicit NOT IMPLEMENTED marker. Implementation begins only after alpha release of the current five operators and first production fintech operator adoption.

**Decision 8 -- Schema specification is published at schema.ontai.dev.**
All community-facing schema follows the four Governor decisions: structured reference objects {group, kind, version}, x-ont-stability alpha, x-ont-layer plus x-ont-depends-on, rationale in GovernanceEvent only.

**Decision 9 -- Living documentation reframing is canonical.**
The founding document preamble section "The Cluster Is the Documentation" is the primary value proposition. Infrastructure governance is described as the consequence, not the purpose. All marketing, README, and summary documents must reflect this framing.

**Decision 10 -- kro and Cedar positioning.**
kro is positioned as a resource composition engine two layers below Guardian and Conductor. ONT operators may use kro internally. kro is not a competitor. Cedar is the strongest candidate for policy expression inside Guardian EPG inputs. Neither competes with ONT's governance layer.

**Decision 11 -- Schema-First Development Contract (locked April 2026).**
ontai-schema is the authoritative source for all CRD field definitions. The Go type implementations in each operator repo are implementations of the schema, not the source of it. Three enforcement rules:
1. Schema changes go to ontai-schema first, before any operator repo implementation.
2. Each operator repo CI validates CRD YAML against schema.ontai.dev before merge.
3. Implementation PRs adding fields absent from the schema are blocked until the schema PR merges first.
This closes the gap between the ONT governance claim (schema is the contract) and how ONT develops. ONT eats its own cooking at the schema layer from this point forward.

**Decision 12 -- Three-image Conductor model (locked April 2026).**
Compiler: debian-slim. GitOps pipeline only. Never deployed to cluster.
Conductor execute mode: debian-slim. Requires shell environment for SOPS, Helm, and Kustomize. Runs as short-lived Kueue-managed Jobs on the management cluster only.
Conductor agent mode: distroless Go only. Deployed to ont-system on every cluster. No shell. No scripts. Ever.
The execute image must never be distroless. The agent image must never be debian-slim. These are architectural invariants, not preferences. Existing implementations are grandfathered but must align on next touch.

**Decision G -- All cross-operator CRD schemas are owned exclusively by seam-core (locked April 2026).**
All CRD type definitions for the Seam platform are declared and owned by seam-core under infrastructure.ontai.dev/v1alpha1. Individual operators own only the status subresource fields and reconciliation behavior within their declared domain boundary. The migrated types are: InfrastructureRunnerConfig, InfrastructurePackReceipt (formerly runner.ontai.dev), InfrastructureClusterPack, InfrastructurePackExecution, InfrastructurePackInstance, InfrastructurePackBuild (formerly infra.ontai.dev), InfrastructureTalosCluster (formerly platform.ontai.dev), and DriftSignal. API group for all migrated types: infrastructure.ontai.dev/v1alpha1. Kind names carry the Infrastructure prefix. Resource names are lowercase plural with the infrastructure prefix retained: infrastructurerunnerconfigs, infrastructurepackreceipts, infrastructureclusterpacks, infrastructurepackexecutions, infrastructurepackinstances, infrastructurepackbuilds, infrastructuretalosclusters, driftsignals. No operator may define a CRD in a non-seam-core-owned group for types consumed by more than one operator. Migration completed Phase 2B, 2026-04-25.

**Decision H -- Conductor drift detection and cluster deletion invariants (locked April 2026).**
Conductor, regardless of role, is the reconciliation authority for the governance state of its cluster. When it detects a delta between declared state held in the governance CRs -- RBACPolicy, RBACProfile, PermissionSet, PackReceipt, TalosCluster -- and actual deployed resources on the cluster, it writes the drift reason into the relevant CR status and signals the management cluster. It does not remediate directly. The management cluster initiates corrective jobs through the normal operator paths: wrapper for pack redeployment, platform for cluster operations. No resource deployed outside seam awareness survives a reconciliation cycle. This loop is symmetric: conductor role=tenant watches its cluster and signals management; conductor role=management watches the management cluster and handles corrective jobs directly. When a governance CR is deleted from the management cluster, conductor role=management orchestrates a fixed teardown sequence in the tenant cluster: wrapper components first (pack instances, pack executions, runner configs), then guardian components (rbac profiles, permission sets, rbac policies, permission snapshot), then the TalosCluster CR. This order is non-negotiable. For bootstrapped clusters, deletion is permanent -- the cluster is decommissioned and infrastructure torn down. For imported clusters, deletion severs the management relationship only -- the cluster continues to exist but is no longer governed by ONT. This is a divorce, not a destruction. The distinction is derived from the TalosCluster spec mode field: mode=bootstrap means permanent decommission, mode=import means severance only.

---

## 7. Governor Directives

### Context Compaction Safety Protocol

This directive is authored by the Governor and may not be amended or overridden by any other role.

**Rule 1 - Threshold:** When the active context window reaches approximately 95 percent capacity, the current agent must not drive toward compaction. It must pause work and execute the compaction safety protocol before any further action.

**Rule 2 - LOCAL-CONTEXT.md creation:** The agent creates or overwrites ~/ontai/LOCAL-CONTEXT.md with the following content in order:
- Session identifier and branch name currently active
- Repos with uncommitted or unpushed changes and their current state
- The exact next step that was about to be executed when the threshold was reached
- Any diagnostic findings recorded so far in the session that have not yet been committed to PROGRESS.md
- The list of backlog items still open in the current session

**Rule 3 - CLAUDE.md reference:** LOCAL-CONTEXT.md must be listed as the first read in the CLAUDE.md agent startup sequence, before CONTEXT.md. Agents starting a new context window must read LOCAL-CONTEXT.md first and resume from the recorded next step without asking the human to repeat what was already decided.

**Rule 4 - Governor authority:** Only the Governor role may create, amend, or delete LOCAL-CONTEXT.md protocol entries in CLAUDE.md. Individual controller, schema, or runner engineer roles must follow the protocol but may not modify it.

**Rule 5 - Cleanup:** When a session branch is fully merged to main and confirmed green, the agent must delete LOCAL-CONTEXT.md and commit the deletion to the ontai root main branch. A stale LOCAL-CONTEXT.md after merge is an invariant violation.

*2026-04-20 -- Context compaction safety protocol established.*

### e2e CI Contract and Skip-Reason Standard

**Rule 1 - Suite location:** Every operator repo carries its e2e suite under test/e2e/ with a Makefile target named e2e.

**Rule 2 - Environment gate:** All specs skip automatically when MGMT_KUBECONFIG is absent. No spec may attempt a cluster connection without this gate.

**Rule 3 - Skip-reason format:** Every skipped spec must reference the exact backlog item ID or cluster condition that would promote it to live. The required format is:
  Skip("requires <condition> and <BACKLOG-ID> closed")
Generic TODO comments are an invariant violation. A PR that introduces a spec with a generic TODO skip is blocked until corrected.

**Rule 4 - Promotion:** When a backlog item closes, any engineer may grep the e2e suites for that item ID and identify every promotable stub. Promotion from stub to live happens in the cluster verification session for that item, not in the feature session.

**Rule 5 - Co-shipment:** The engineer who writes a feature writes the e2e stub for it in the same PR. A feature PR without an e2e stub requires Governor approval to merge.

**Rule 6 - CI reporting:** The CI script runs make e2e on every PR. The count of skipped specs is reported in the PR summary. A PR that reduces the live spec count without a Governor-approved deferral is blocked.

*2026-04-20 -- e2e CI contract and skip-reason standard established.*

---

## 8. Amendment History

2026-03-30 -- Two-binary architecture. INV-022 through INV-026 added. Signing chain added to agent model.
2026-03-30 -- CAPI adoption and Path B ruling. INV-013 amended with named reconciler exceptions.
2026-04-03 -- Seam rebranding. All operator/repo names updated. INV-025 removed. Repo names table added.
2026-04-04 -- Lineage as First-Class Platform Primitive directive. Decisions 1-6 locked.
2026-04-18 -- Locked Architectural Decisions section. Decisions 7-10 added. Working preferences enumerated.
2026-04-20 -- Context Compaction Safety Protocol directive established.
2026-04-20 -- e2e CI Contract and Skip-Reason Standard directive established.
2026-04-20 -- Decision 11 (Schema-First) and Decision 12 (three-image model) locked. INV-022 updated.
2026-04-20 -- Constitutional refactor: root CLAUDE.md scoped to ROOT content only. Repo CLAUDE.md files updated. domain-core added to component table.
2026-04-24 -- Decision H locked. Conductor drift detection, deletion cascade order, and bootstrap-versus-import deletion invariants established.
2026-04-25 -- Decision G locked. All cross-operator CRD schemas migrate to seam-core under infrastructure.ontai.dev. INV-010 updated to reflect seam-core as schema authority. Phase 2B complete.
2026-04-25 -- INV-023 added. Operator Deployments and enable bundles always use :dev tag in lab/development. Custom per-build tags are never written into any committed artifact.

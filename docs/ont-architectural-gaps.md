
# ONT Operator Schema Design Document

**Version:** v0.1-alpha  
**Status:** Architectural Draft  
**Scope:** Domain Core through Application Operator, Seam Family Integration  

---

## Table of Contents

1. Governing Philosophy
2. Configuration Classification
3. Layer 1: Domain Core CRDs
4. Layer 2: Application Domain Core CRDs
5. Layer 3: Application Operator Extension
6. Layer 4: Seam Family Integration
7. Relationship Topology Tiers
8. Binding Stability Model
9. Candidate Selection Strategy
10. Total Ordering Invariant
11. AppProfile: The Composition Root
12. Lifecycle Ordering
13. Vortex: First Seam-Backed Application Consumer

---

## 1. Governing Philosophy

ONT (Operator Native Thinking) expresses every domain lifecycle as a Kubernetes operator: declarative, versioned, and auditable. This document defines the schema architecture that translates universal domain primitives into application-layer CRDs and governs how those CRDs integrate with the Seam infrastructure layer.

Every CRD in this system satisfies three properties:

**Declarative:** The desired state is expressed in etcd as a structured record, not as a runtime instruction.

**Traced:** Every application-layer CRD carries a mandatory reference to its Domain Core parent. No CRD is an island. No authority is self-declared.

**Auditable:** Every state transition is recorded with a timestamp, an attributing actor, and a lineage reference. The audit trail is complete from domain intent to deployed binding.

The framework is organized into four layers. Each layer depends on the layer above it. No layer reimplements the layer above it. The dependency flows strictly downward.

---

## 2. Configuration Classification

All configuration is classified into one of two categories before schema design begins.

### Runtime Configuration

Runtime configuration is hot-patchable. It does not require a restart. It does not carry identity, trust, or structural wiring. It is projected into Pods via ConfigMap and watched by the operator for live reconciliation. Tunable values, feature toggles, log verbosity, and per-request timeout adjustments are runtime configuration.

Runtime configuration is not a CRD. It is not part of this document.

### Onetime Configuration

Onetime configuration is structural. It defines what the application is, who it trusts, how it is wired, what it consumes, and how it is governed. Changing any onetime configuration is a versioned lifecycle event, not a patch. Every onetime configuration category is a first-class CRD stored in etcd, reconciled by an operator, and traced to a Domain Core parent.

All CRDs described in this document are onetime configuration.

---

## 3. Layer 1: Domain Core CRDs

Domain Core CRDs are the canonical authority. They are defined at the ONT Web level and owned by the domain-core. Application operators read them. Application operators never write them.

These CRDs express the nine universal domain primitives along with Semantic DNS. They exist before any application is deployed. They define the governance envelope within which all application-layer CRDs must operate.

### DomainIdentity

Registers a participant in the entire ONT ONT Web. Carries the SPIFFE trust domain, ONT Web-level subject reference, and operator-owner declaration. Every application-layer identity traces to a DomainIdentity as its root authority.

### DomainBoundary

Declares organizational scope, tenant assignment, and cluster-level placement authority for a domain participant. Defines the outer wall within which all lower-layer boundary declarations must fit.

### DomainPolicy

Declares governance rules that apply to interactions between domain participants. Sets the floor for retry behavior, circuit breaking, rate limiting, and access control modes. Application-layer policy declarations cannot contradict or exceed DomainPolicy.

### DomainRelationship

Declares that a typed dependency relationship exists between two domain participants. Defines the relationship as a named, versioned contract. Application-layer topology wiring must trace every entry to a DomainRelationship as its authority. An application cannot wire to a service that has no declared DomainRelationship.

### DomainEvent

Declares event contracts owned at the domain level: the event type, its producer authority, its schema version, and its consumer eligibility rules. Application-layer event schema bindings must trace to a DomainEvent. An application cannot produce or consume an event without a parent DomainEvent.

### DomainWorkflow

Declares ordered phase sequences at the domain level: the phases, their entry conditions, their terminal states, and the authority that governs phase transitions. Application-layer workflow declarations translate these into executable Conductor Job sequences.

### DomainResource

Declares the quota envelope available to a domain participant: compute, memory, storage class eligibility, and Kueue resource flavor preferences. Application-layer resource claims must not exceed the ceiling set by the parent DomainResource.

### DomainAudit

Declares the audit floor enforced by Guardian for a domain participant. Defines the minimum event granularity, retention requirements, and transport path for audit events. Application-layer audit policies cannot be declared below this floor.

### DomainSemanticNameService

Every participant in the ONT Web must be resolvable not just by its technical address but by its declared meaning. A service is not located by its IP or its DNS hostname alone. It is located by what it is within the domain: its identity tier, its boundary coordinates, its relationship class membership, and its semantic role in the domain graph.

---

## 4. Layer 2: Application Domain Core CRDs

Application Domain Core CRDs are the standard translation layer. Every application operator consumes these CRDs. No operator skips this layer or reimplements it.

The translation rule is strict: each Domain Core CRD produces exactly one Application Domain Core CRD just like how seam-core done with infrastructure domain. The Domain Core CRD sets the floor and the schema authority. The Application Domain Core CRD inherits that floor, narrows the scope to a single deployable service, and carries a mandatory parent reference back to its Domain Core authority.

### AppBoundary (translates DomainBoundary)

Narrows organizational scope to the specific namespace, cluster assignment, and environment tier this service occupies within the domain boundary. AppBoundary cannot declare a scope wider than its parent DomainBoundary permits. AppBoundary is the outermost shell of the application's existence in the ONT Web. It must reach Ready before AppIdentity can be created.

### AppIdentity (translates DomainIdentity)

Narrows ONT Web-level registration to a single deployable service instance. Carries service name, version, and operator-owner. Inherits the SPIFFE trust domain from its parent DomainIdentity. Cannot claim an identity that does not trace to an existing DomainIdentity. AppIdentity is the root anchor of the application-layer CRD family. All other Application Domain Core CRDs reference it. No sibling CRD reaches Ready until AppIdentity is Ready.

### AppPolicy (translates DomainPolicy)

Inherits domain governance rules and adds service-level specifics: retry envelopes, circuit breaker thresholds, and rate limit declarations scoped to this service. Guardian validates at reconciliation that AppPolicy does not contradict or exceed the governing DomainPolicy. The application team declares intent. Guardian enforces the ceiling.

### AppTopology (translates DomainRelationship)

Translates declared domain relationships into concrete service wiring: endpoints, protocols, and connection parameters. Every entry in AppTopology must carry a reference to a DomainRelationship as its authority. An application cannot wire to a service that has no declared domain-level relationship. Broken relationships surface as condition transitions, not as silent failures. The full relationship topology model governing AppTopology is described in Section 7.

### AppEventSchema (translates DomainEvent)

Translates domain event contracts into the application's specific producer or consumer binding: broker reference, topic name, and schema version pin. An application cannot produce or consume an event without a parent DomainEvent. Schema compatibility between producer and consumer AppEventSchema CRDs is validated before AppWorkflow proceeds to the schema bootstrap phase.

### AppWorkflow (translates DomainWorkflow)

Translates domain phase sequences into Conductor-executable declarations: entry conditions, Kueue Job parameters, and terminal state transitions. Conductor schedules AppWorkflow executions against the authority of the parent DomainWorkflow. AppSchemaBootstrap is a specialization of this primitive, expressed as a first-run workflow phase.

### AppResourceProfile (translates DomainResource)

Claims a specific portion of the domain quota envelope for this service instance. The Platform Operator validates that the claim does not exceed the ceiling set by the parent DomainResource. AppResourceProfile is immutable after the application reaches Running state. Changes require a version bump and a controlled redeployment, enforcing the onetime classification.

### AppAuditPolicy (translates DomainAudit)

Declares the service-level audit emission contract: which state transitions emit audit events and at what granularity. Cannot be declared below the floor set by the parent DomainAudit. Guardian enforces the floor. Audit events flow through Conductor's two-tier transport to the management cluster aggregator.

---

## 5. Layer 3: Application Operator Extension

Application Domain Core CRDs are standard and shared. Every application operator consumes them as-is. Extension is permitted only where an operator has concerns that the standard layer cannot express.

### Extension Rules

An operator-specific CRD must carry a reference to the Application Domain Core CRD it extends. It adds schema fields. It does not replace the base. The Application Operator Framework never sees extension fields. Extension lives in the operator's own schema and is the operator's internal concern.

### Non-Extensible CRDs

AppIdentity and AppBoundary are not extensible at this layer. Both carry Guardian trust resolution and are structurally immutable once reconciled. Operators that need identity-adjacent fields must declare them in their own CRDs with a reference to AppIdentity, not as extensions of it.

### Extension Examples by Concern

A data layer operator may extend AppTopology with storage-engine-specific fields that do not belong in the standard wiring schema.

A messaging operator may extend AppEventSchema with partition strategy and consumer group declarations specific to its broker.

A workflow-heavy operator may extend AppWorkflow with checkpoint and rollback declarations that the standard phase model does not cover.

---

## 6. Layer 4: Seam Family Integration

The Seam core is the infrastructure domain of the ONT platform. It is not a separate class of operator. It is the set of application operators including Guardian whose SeamMembership has been Guardian-provisioned (We solved chicken-egg problem with bootstrap sequencing in management cluster). Any application operator that meets the membership criteria and receives Guardian's Seam-tier PermissionSnapshot resolution joins the Seam family through that join point.

### SeamMembership

SeamMembership is an existing Seam Core construct. It is the join mechanism between the application layer and the Seam infrastructure domain. A SeamMembership declaration references the operator's AppIdentity as its application-layer anchor. Guardian evaluates the declaration against the operator's AppPolicy and AppBoundary, then resolves a Seam-tier PermissionSnapshot if the evaluation passes.

The operator does not author its own Seam authority. It declares membership. Guardian fulfills it. This is identical in principle to how any application operator receives trust: declared intent, Guardian-resolved authority.

### What SeamMembership Grants

Upon Guardian resolution, a Seam family member gains read access to all operator CRDs across tenant namespaces scoped by its declared AppBoundary, and write access scoped to its own portal state or infrastructure governance CRDs as defined in its PermissionSnapshot. No operator authors these permissions. Guardian derives them from the operator's declared AppPolicy and DomainPolicy floor.

### Seam Family Operator Roles

The six Seam Operators and their infrastructure governance scopes are established separately. What this document defines is that each of them, if expressed as an application-layer consumer, follows the identical AppProfile path described here. The Seam family is not exempt from the application domain framework. It is the first and most authoritative consumer of it.

---

## 7. Relationship Topology Tiers

AppTopology is the application-layer expression of DomainRelationship. In real distributed systems, not all relationships are fully known at declaration time. The framework addresses this through a tiered relationship model. All tiers share one invariant: no interaction enters the ONT Web without an authority reference in etcd. What varies across tiers is the timing and mechanism of authority establishment, not the existence of authority.

### Tier 1: Declared Structural

This is the default and the majority case. AppTopology references a specific DomainRelationship. The counterpart is named, the protocol is declared, and the wiring is fully resolved at authoring time. Permanent, stable, fully auditable from declaration time forward.

### Tier 2: Declared Class with Deferred Binding (RelationshipClass)

Used when a service knows the class of its dependency but not the specific instance. A cache consumer knows it needs a cache tier. It does not know which specific cache instance it will bind to at declaration time.

A RelationshipClass is a DomainRelationship variant that declares a typed class of interaction without naming a specific counterpart. AppTopology references the class. Binding resolves at admission by the Platform Operator against the bounded candidate set.

A RelationshipClass is valid at admission only if all seven conditions are satisfied:

**Condition 1:** The candidate set is non-empty.

**Condition 2:** The candidate set is finite.

**Condition 3:** The candidate set is enumerable from declared etcd state at admission time. Runtime state does not participate in resolution.

**Condition 4:** The candidate set is within the cardinality ceiling set by the governing DomainPolicy.

**Condition 5:** Every candidate satisfies both Boundary scope and Policy scope constraints simultaneously.

**Condition 6:** The binding semantics are explicitly declared as SnapshotBinding or ContinuousBinding as described in Section 8.

**Condition 7:** The candidate selection strategy is explicitly declared, belongs to the framework vocabulary, and produces a verifiably deterministic result against the current eligible pool as described in Sections 9 and 10.

If any condition fails, the RelationshipClass is rejected. If the failure is caused by runtime dependency in Condition 3, rejection is automatic and escalation to Tier 4 is produced. The rejection artifact becomes the RelationshipAdmissionRequest. The team does not refile from scratch.

**The Boundedness Invariant for Tier 2**

A RelationshipClass must resolve to a candidate set that is bounded by two dimensions simultaneously, both declared at authoring time:

Boundary scope constrains the eligible set to AppIdentity CRDs whose AppBoundary falls within the declared scope.

Policy scope constrains further by requiring that every candidate's AppPolicy is compatible with the declared relationship class policy.

A RelationshipClass that declares a Boundary scope spanning the entire ONT Web is functionally unbounded. The Platform Operator applies a maximum candidate set size derived from the governing DomainPolicy. If the resolved set exceeds that size, the class is treated as unbounded and rejected. Teams cannot raise their own ceiling. Guardian owns all ceiling values.

### Tier 3: Workflow-Scoped Temporal (TemporalRelationship)

Used for dependencies that exist only for the duration of a workflow phase: migration runners, schema bootstrap jobs, canary shadow connections, and similar ephemeral wiring.

A TemporalRelationship is declared inside the AppWorkflow CRD, not in AppTopology. Its authority is the parent DomainWorkflow, not a DomainRelationship. It is admitted by Guardian at workflow scheduling time, exists for the duration of the declaring phase, and is automatically revoked when the phase reaches terminal state.

Conductor owns the TemporalRelationship lifecycle because Conductor schedules the workflow, knows the phase boundaries, and issues and revokes the relationship binding as part of Job management. AppTopology remains clean: structural persistent wiring lives there. Ephemeral wiring lives in AppWorkflow. The two surfaces do not mix.

### Tier 4: Guardian-Admitted Emergent (RelationshipAdmissionRequest)

Used for cross-domain emergent behavior: two services from different domains begin interacting in ways that were not declared at design time. The interaction is legitimate but no DomainRelationship exists between the participants.

A RelationshipAdmissionRequest is submitted to Guardian declaring the two participants, the interaction type, and the justification. Guardian evaluates it against both parties' DomainPolicy for bilateral compatibility. A human-at-boundary approval step is required before the relationship is admitted.

Once admitted, the RelationshipAdmissionRequest produces a first-class DomainRelationship with full lineage to the admission event. The audit trail includes the admission event, the approver identity, the justification, and the timestamp.

Vortex is the natural surface for this flow. AI-curated risk assessment of the proposed relationship is presented to the human reviewer before Guardian acts.

Tiered approval within Tier 4: low-risk classes that satisfy both parties' DomainPolicy without ambiguity may be auto-admitted by Guardian without a human step. High-risk classes require explicit human approval via Vortex. The risk tier is evaluated by Guardian against DomainPolicy, not declared by the submitting team.

---

## 8. Binding Stability Model

When a RelationshipClass binding is recorded in etcd, that record must declare what kind of truth it represents. A binding is either a historical fact or a living assertion. These are semantically different and must not be stored under the same record structure without declaration.

Binding semantics are a first-class declared property of the RelationshipClass at authoring time. A RelationshipClass that does not declare binding semantics is rejected at authoring time, not at admission time.

### SnapshotBinding

The resolution at admission time is recorded as an immutable fact in etcd. The binding record carries a resolution timestamp and the exact candidate set at that moment. If candidates drift after admission, the binding record does not change.

The framework observes drift and produces a Diverged condition on the AppTopology CRD. Drift does not automatically trigger re-admission. The application operator decides whether to accept the drift, request re-resolution, or escalate. Re-resolution requires an explicit version bump on the AppTopology CRD, triggering a new admission cycle.

If a SnapshotBinding enters Diverged and the operator does not act, the divergence is recorded as a governance event in Guardian's audit trail. The snapshot model's integrity is preserved through observation and escalation, not through forced resolution.

SnapshotBinding is the correct mode for trust wiring, schema-pinned dependencies, audit-critical relationships, and any relationship where the historical fact of what was connected carries governance weight equal to what is connected now.

### ContinuousBinding

The resolution at admission time is recorded as a contract assertion in etcd. The binding record carries the constraint declaration that produced the candidate set: the Boundary scope, the Policy scope, and the cardinality envelope. The framework continuously re-evaluates the candidate set against those constraints.

When candidates drift, the selection strategy declared in the RelationshipClass is re-applied against the updated eligible pool. The resulting active set change is recorded in etcd as a binding transition event carrying the previous set, the new set, the trigger that caused re-evaluation, and the timestamp.

Drift produces condition transitions based on what changed:

A candidate disappears and the remaining set satisfies the cardinality floor: the binding enters Degraded condition. The application continues operating.

A candidate disappears and the remaining set falls below the cardinality floor: the binding enters Invalid condition. The application operator must act.

A candidate's policy changes making it ineligible: that candidate is removed from the active set. Floor evaluation proceeds as above.

A new candidate appears that satisfies the class constraints: it is admitted to the active set automatically, up to the cardinality ceiling, according to the declared selection strategy. This is the key behavioral distinction from SnapshotBinding: the active set can grow as well as shrink.

ContinuousBinding is the correct mode for service pool relationships, replica sets, dynamic cache tiers, and any relationship where current validity is more operationally significant than historical consistency.

### Shared Condition Vocabulary

Both binding modes produce conditions on the AppTopology CRD using a shared vocabulary:

**Stable:** All candidates satisfy all constraints. Current state matches the binding record.

**Degraded:** Candidate set has shrunk but remains above the cardinality floor. ContinuousBinding only.

**Diverged:** Current state differs from the snapshot. SnapshotBinding only. Historical record remains valid. Operator decision required.

**Invalid:** Candidate set has fallen below the cardinality floor, or a policy violation has been detected that the framework cannot resolve without intervention. Both binding modes.

**Resolving:** A re-resolution or re-admission cycle is in progress. Transitional state.

---

## 9. Candidate Selection Strategy

When a RelationshipClass ceiling is lower than the eligible pool size, the framework must determine which eligible candidates become the active set. This determination is a governance concern, not a runtime concern. It must be declared, deterministic, and reconstructable from etcd state alone.

Candidate selection strategy is a first-class declared property of the RelationshipClass. A RelationshipClass that does not declare a selection strategy is rejected at authoring time.

Runtime state (what is currently healthy, what is currently reachable, what is currently responding) does not participate in candidate selection. Health-aware routing is the ONT Web layer's concern. The selected set is always reconstructable from declared etcd state. If selection admitted runtime health as an input, an auditor examining etcd could not reconstruct which candidates were selected at any given moment.

### Selection Strategy Vocabulary

**Deterministic-Stable**

The selection algorithm is a pure function of declared properties in etcd: AppIdentity name, Boundary coordinates, and a declared priority field on the candidate's AppIdentity. No runtime state participates. Given the same eligible pool and declared fields, any two implementations produce identical output.

When new candidates appear in a ContinuousBinding, they do not automatically displace existing selections. The existing set is preferred until it falls below the cardinality floor. Replacement follows the declared priority and lexicographic tie-breaking rules.

This is the default for SnapshotBinding.

**Deterministic-Locality**

Selection favors candidates whose AppBoundary coordinates are closest to the selecting application's AppBoundary coordinates. Locality is evaluated against declared Boundary fields in etcd, not against runtime network measurements. Same namespace ranks highest. Same cluster ranks second. Same domain ranks third. Ties within each locality tier are broken by AppIdentity name in lexicographic ascending order.

**Deterministic-Priority**

Candidates carry a declared priority value as a field in their AppIdentity or AppResourceProfile. Selection fills the active set in descending priority order. Ties are broken by AppIdentity name in lexicographic ascending order.

**Declared-Rotation**

The active set rotates according to a rotation policy declared in the RelationshipClass. The rotation sequence is deterministic: given the eligible pool, the rotation policy, and the current rotation index recorded in etcd, any observer can compute which candidates are active at any moment. The rotation index is an etcd field updated on each rotation event. Each rotation transition is recorded as a binding transition event.

---

## 10. Total Ordering Invariant

Determinism in candidate selection requires a total ordering of the eligible pool. A partial ordering produces cases where two candidates are equally ranked with no defined resolution. Two independent implementations of the same strategy against the same pool would then be free to produce different output. This breaks the reconstructability guarantee.

The invariant is:

**Every selection strategy must define a sort key sequence that guarantees a strict total order over any eligible pool. No two candidates may be equal under the full key sequence. Every tie at any primary key must be resolved by the next key in the sequence. The final key in every strategy is AppIdentity name in lexicographic ascending order.**

AppIdentity name is the universal terminal tie-breaker because it is unique within the ONT Web by definition. No two AppIdentity records share the same name within the same namespace and cluster scope. The terminal key therefore always resolves, which means the full sort key sequence always resolves, which means the ordering is always total.

A RelationshipClass that declares a custom selection strategy must demonstrate that its sort key sequence terminates in AppIdentity name or in another field that is guaranteed unique within the eligible pool. Strategies that cannot demonstrate this property are rejected at authoring time.

The Platform Operator validates total ordering compliance at admission time by evaluating the selection strategy against the current eligible pool and confirming that the result is a sequence with no ties at the terminal position.

---

## 11. AppProfile: The Composition Root

AppProfile is the single CRD that an application operator authors to declare its complete onetime configuration needs. It is the unit of registration for any service entering the ONT ONT Web.

AppProfile owns or references all night Application Domain Core CRDs including SDNS. It does not reach Ready until every child CRD is in a terminal Ready state. This is the phase gate model: identical in principle to Guardian's bootstrap sequencing for operator admission.

AppProfile is what Vortex and every future application operator submits to the framework. It is also what the Application Operator Framework controller monitors as the single status surface for the application's full onetime configuration health.

---

## 12. Lifecycle Ordering

The Application Operator Framework enforces a strict reconciliation order. No CRD proceeds to the next phase until the preceding phase's CRDs have reached Ready.

### Phase 1: Scope Establishment

AppBoundary is created and reconciled first. It defines the outer wall. Nothing else can exist without it.

### Phase 2: Identity Registration

AppIdentity is created after AppBoundary reaches Ready. It inherits the SPIFFE trust domain from DomainIdentity and registers the service in the ONT Web.

### Phase 3: Authority Resolution (parallel)

Once AppIdentity reaches Ready, three CRDs reconcile in parallel:

AppPolicy is evaluated by Guardian against DomainPolicy ceiling.

AppResourceProfile is validated by the Platform Operator against the DomainResource ceiling.

AppAuditPolicy is evaluated by Guardian against the DomainAudit floor.

AppObservability is injected by Conductor or the Platform Operator. It is not authored by the application operator team.

### Phase 4: Structural Wiring

AppTopology reconciles after AppPolicy reaches Ready. Each topology entry is resolved against its DomainRelationship authority. RelationshipClass entries undergo the seven-condition bounded resolution check.

### Phase 5: Event Contract Registration

AppEventSchema reconciles after AppTopology reaches Ready. Schema compatibility between declared producer and consumer bindings is validated.

### Phase 6: Workflow and Bootstrap Execution (parallel)

AppWorkflow is submitted to Conductor for phase scheduling via Kueue once AppEventSchema reaches Ready. The schema bootstrap phase of AppWorkflow executes as a Kueue Job against the topology declared in AppTopology.

### Phase 7: Behavioral Configuration

AppBehavior reconciles independently once AppIdentity is Ready. It carries no dependency on topology, trust, or event schema.

### Phase 8: Profile Completion

AppProfile transitions to Ready when all child CRDs have reached terminal Ready state across all phases.

---

## 13. Vortex: First Seam-Backed Application Consumer

Vortex occupies a unique position in the ONT architecture. It is simultaneously a Seam family operator (governed by the Seam infrastructure domain) and the first application to be governed by the Application Operator Framework it will eventually surface to users through its Portal UI.

This dual position means Vortex demonstrates the framework's coherence by submitting a complete AppProfile against itself. The portal that governs application configuration is itself governed by every rule it will enforce.

### Vortex Relationship Chain

```
DomainIdentity (management-tier portal participant)
  translates to
AppIdentity (Vortex service instance, management tier, seam-core as owner)
  extended by
VortexProfile (portal tier, NLP endpoint binding, manifest review workflow mode)
  joined via
SeamMembership (references AppIdentity, Guardian resolves Seam-tier PermissionSnapshot)
```

### Vortex AppProfile Expressed

**AppBoundary:** Management cluster, management namespace, no tenant scope. DomainBoundary parent is the management-tier organizational scope.

**AppIdentity:** Vortex service, version-pinned, seam-core as declared owner. Inherits SPIFFE trust domain from management-tier DomainIdentity.

**AppPolicy:** Read access across all operator CRDs in tenant namespaces scoped by AppBoundary. Write access scoped to Vortex portal state CRDs only. Guardian validates against DomainPolicy ceiling for management-tier portal participants.

**AppTopology:** Three structural wirings declared, each tracing to a DomainRelationship authority:

- Guardian gRPC PermissionService (SnapshotBinding, trust-critical)
- GitOps webhook endpoint (ContinuousBinding, operational)
- CNPG database instance (SnapshotBinding, schema-pinned)

**AppEventSchema:** Vortex owns the translation contract between the three event tiers. Three event types declared:

- DomainEvent (human intent arriving at the portal via the UI surface)
- InfrastructureEvent (approved manifest dispatched to GitOps after human review)
- ApplicationEvent (downstream operator reaction received and surfaced back to the portal)

Each type traces to its parent DomainEvent. Vortex is a producer of InfrastructureEvent and a consumer of ApplicationEvent. It is the receiving surface for DomainEvent.

**AppWorkflow:** Schema migration against the CNPG instance runs as a Kueue Job via Conductor before Vortex is admitted to serve traffic. Traces to the management-tier DomainWorkflow for service bootstrap. The migration Job must reach terminal success state before the AppWorkflow phase advances and the Vortex Pod is admitted.

**AppResourceProfile:** Management-tier quota claim. Validated against DomainResource ceiling by the Platform Operator. Immutable after Vortex reaches Running state.

**AppAuditPolicy:** Every manifest review decision, approval, rejection, and GitOps dispatch is a declared audited state transition. Guardian enforces the audit floor for management-tier participants. Audit events flow through Conductor's two-tier transport to the management cluster aggregator.

### Vortex as Framework Proof

Every rule in this document applies to Vortex without exception. Vortex's RelationshipClass entries (if any are declared for dynamic service pool wiring) satisfy all seven admission conditions. Its SnapshotBinding entries for trust-critical topology are immutable and Diverged-condition monitored. Its selection strategies declare total ordering with AppIdentity name as the terminal tie-breaker.

Vortex will eventually render the AppProfile lifecycle to users through its Portal UI: AI-curated manifests reviewed and approved by a human before GitOps delivers them. The CRD domain model defined in this document is exactly what Vortex will surface, validate, and hand off to the GitOps layer. The framework does not just manage what was planned. It safely admits what emerges. Vortex, as the first consumer, proves both.

---

## Appendix A: CRD Relationship Map

```
Domain Core Layer
  DomainIdentity       parent of       AppIdentity
  DomainBoundary       parent of       AppBoundary
  DomainPolicy         floor for       AppPolicy
  DomainRelationship   authority for   AppTopology
  DomainEvent          authority for   AppEventSchema
  DomainWorkflow       authority for   AppWorkflow
  DomainResource       ceiling for     AppResourceProfile
  DomainAudit          floor for       AppAuditPolicy
  DomainSemanticNameService 

Application Domain Core Layer
  AppBoundary          prerequisite for   AppIdentity
  AppIdentity          root anchor for    all sibling CRDs
  AppPolicy            Guardian-validated, references AppIdentity
  AppTopology          wiring layer, references AppIdentity + DomainRelationship
  AppEventSchema       contract layer, references AppIdentity + DomainEvent
  AppWorkflow          execution layer, references AppIdentity + DomainWorkflow
  AppResourceProfile   quota layer, references AppIdentity + DomainResource
  AppAuditPolicy       governance layer, references AppIdentity + DomainAudit
  AppProfile           composition root, owns all above
  AppSemanticNameService wired to DomainSemanticNameService

Seam Integration Layer
  SeamMembership       joins AppIdentity into Seam family
  SeamMembership       triggers Guardian Seam-tier PermissionSnapshot resolution
```

## Appendix B: Relationship Tier Summary

| Tier | Name | Authority Source | Lifecycle | Owner |
|------|------|-----------------|-----------|-------|
| 1 | Declared Structural | DomainRelationship | Permanent | Application Operator |
| 2 | RelationshipClass | DomainRelationship class variant | Admission-resolved | Platform Operator |
| 3 | TemporalRelationship | DomainWorkflow | Phase-scoped | Conductor |
| 4 | RelationshipAdmissionRequest | Guardian admission event | Admission-produced DomainRelationship | Guardian + Human |

## Appendix C: Binding Mode Decision Guide

| Relationship Concern | Binding Mode |
|---------------------|-------------|
| Trust wiring | SnapshotBinding |
| Schema-pinned dependency | SnapshotBinding |
| Audit-critical relationship | SnapshotBinding |
| Service pool | ContinuousBinding |
| Dynamic cache tier | ContinuousBinding |
| Replica set | ContinuousBinding |
| Ephemeral workflow dependency | TemporalRelationship (no binding mode) |

## Appendix D: Selection Strategy Decision Guide

| Concern | Strategy |
|---------|----------|
| Stable, audit-critical pool | Deterministic-Stable |
| Latency-sensitive service pool | Deterministic-Locality |
| Prioritized failover | Deterministic-Priority |
| Load distribution across equivalent candidates | Declared-Rotation |

This is the foundational ONT philosophy document - the Application Operator Framework that sits above the Seam infrastructure domain. Let me map the conflicts and gaps honestly.

---

## Layer Alignment - What Exists vs What the Document Requires

**Seam is Layer 1+2 of the infrastructure domain, not the application domain.** The document positions Seam correctly as the infrastructure domain that application operators consume via SeamMembership. The current Seam implementation covers:

- `InfrastructureLineageIndex` → maps to the tracing requirement
- `PermissionSnapshot` → maps to the authority resolution in Phase 3
- `RunnerConfig` → maps to `AppWorkflow` execution via Conductor
- `PackExecution/PackInstance` → maps to `AppWorkflow` scheduling

---

## Hard Conflicts

**Conflict 1 - No Application Domain Core layer exists yet**

The document requires `AppBoundary → AppIdentity → AppPolicy → AppTopology` as a strict phase gate sequence before any application enters the ONT Web. Currently there are no CRDs for any of these. Vortex cannot be built without them. This is a full new layer - `domain-core` repo has the primitives but the Application Domain Core translation layer (`app-core` equivalent) does not exist as a repo or as CRDs.

**Conflict 2 - DomainRelationship has no implementation**

`AppTopology` requires every wiring entry to trace to a `DomainRelationship`. Currently seam-core has `DomainRelationship` declared as a primitive type but no reconciler, no admission enforcement, and no wiring validation. The document requires Guardian to validate AppTopology entries against DomainRelationship authority at admission time - this is a significant guardian extension.

**Conflict 3 - SeamMembership does not exist**

The document defines `SeamMembership` as the join mechanism between the application layer and Seam infrastructure. Currently any operator joins Seam by having its RBACProfile provisioned - that is implicit membership. The document requires an explicit `SeamMembership` CRD that Guardian evaluates and resolves into a Seam-tier PermissionSnapshot. This is a new seam-core CRD and a new guardian reconciler.

**Conflict 4 - AppProfile has no equivalent**

`AppProfile` is the composition root - the single CRD an application operator authors. Nothing equivalent exists. The closest is the combination of RBACProfile + TalosCluster + ClusterPack but those are infrastructure-domain concepts, not application-domain concepts.

**Conflict 5 - TemporalRelationship owned by Conductor**

The document assigns Conductor ownership of `TemporalRelationship` lifecycle (Tier 3). Currently Conductor owns RunnerConfig/PackExecution lifecycle but has no concept of relationship binding or admission. This requires extending Conductor's agent mode with relationship lifecycle management.

**Conflict 6 - Candidate Selection Strategy and Total Ordering**

`RelationshipClass` requires seven admission conditions and a declared selection strategy with total ordering. Nothing in the current platform enforces this. Guardian's admission webhook enforces RBAC ownership annotations - it has no concept of topology wiring validation or candidate set evaluation.

---

## Structural Pullbacks in Current Schema

**Pullback 1 - PackInstance.dependsOn is declared but not enforced**

The document requires `DependencyBlocked` condition when a dependency PackInstance is not Ready. The current `PackInstanceReconciler` has `dependsOn` in the spec but no enforcement logic - the field is ignored at runtime.

**Pullback 2 - DSNS is incomplete relative to DomainSemanticNameService**

The document describes DSNS as resolving services by domain meaning - identity tier, boundary coordinates, relationship class membership, semantic role. Currently DSNS only emits A records (cluster VIP), TXT records (role, pack delivery). It has no concept of resolving by relationship class or semantic role. This is a significant gap.

**Pullback 3 - Guardian webhook enforces ownership only**

The document requires Guardian to validate AppPolicy against DomainPolicy ceiling, AppResourceProfile against DomainResource ceiling, AppAuditPolicy against DomainAudit floor, and AppTopology entries against DomainRelationship authority. Currently guardian webhook only validates `ontai.dev/rbac-owner` annotation presence. Ceiling/floor validation does not exist.

**Pullback 4 - No AppObservability injection**

The document says AppObservability is injected by Conductor or Platform - not authored by the application operator. Currently there is no observability injection path. ServiceMonitor CRDs are deferred.

**Pullback 5 - Audit trail is incomplete**

The document requires every state transition to be recorded with timestamp, attributing actor, and lineage reference. Currently guardian writes to CNPG `audit_events` but only for management cluster events. The two-tier Conductor transport for application-layer audit events is implemented (federation channel) but never tested.

---

## Backlog Structure to Imply

**New repos required:**
- `app-core` - Application Domain Core CRDs (AppBoundary, AppIdentity, AppPolicy, AppTopology, AppEventSchema, AppWorkflow, AppResourceProfile, AppAuditPolicy, AppProfile)
- `vortex` - declared but never started

**New CRDs required in existing repos:**
- `seam-core`: SeamMembership, AppSemanticNameService
- `guardian`: SeamMembership reconciler, topology wiring validation, ceiling/floor enforcement
- `conductor`: TemporalRelationship lifecycle, AppWorkflow scheduling

**Schema amendments required:**
- `guardian-schema.md`: Add SeamMembership section, topology admission validation, RelationshipClass seven-condition check
- `seam-core-schema.md`: Add SeamMembership, expand DSNS to semantic resolution
- `conductor-schema.md`: Add TemporalRelationship ownership, AppWorkflow scheduling

---

## On JSON Schema

Yes - the schema can be expressed as JSON Schema (Draft 7 or OpenAPI 3.1 compatible). Since all CRDs are Kubernetes CRDs, the schema is already expressed in OpenAPI v3 format via controller-gen annotations. The full schema surface would be:

- Each CRD's `spec` and `status` as OpenAPI schemas - already generated by `make generate` in each repo
- The inter-CRD relationship graph as a separate JSON document - this does not exist yet and would need to be authored as a governance document separate from the CRD YAMLs

A JSON representation of the full schema graph would be valuable as a machine-readable governance artifact that Vortex can render in its portal UI. Add to backlog: **VORTEX-BL-SCHEMA-GRAPH:** Emit a `schema-graph.json` from the compiler that captures the full CRD relationship topology in JSON Schema format for Vortex to consume.

---

The genesis document is architecturally sound. The Seam implementation covers the infrastructure domain correctly. The application domain layer (Layer 2 and above) is the next major development phase. The pullbacks are all in the upper layers - none contradict the infrastructure foundation we have built.
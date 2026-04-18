# The Vortex Retrieval Interface

## Purpose

Four operators validated the founding document. All four said a version
of the same thing about the memory claim.

Operator Two: the system today does not close the loop described. The
memory is not yet reliable at 3am.

Operator Three: Layer Two and Layer Three are still mostly design. Until
Vortex and Conductor can surface relevant lineage in the review flow,
much of the benefit stays theoretical. This is the make-or-break
implementation piece.

Operator Four: the problem is not that we do not have the data. The
data does not have an API.

This document defines that API.

Not the full Vortex portal. Not the AI authoring interface. Not the
cluster topology visualization. Those are Phase Three of the roadmap.
This document defines the minimal retrieval interface that closes the
gap the four operators named: the three questions that must be
answerable at 3am without running queries you do not know how to write.

- What governance decisions preceded the current state of this system?
- What is the complete dependency graph of the affected component right now?
- What changed in the lineage chain since the last known good state?

When those three questions have governed, contextual, authorized answers
surfaced without excavation, the filing cabinet becomes something an
operator can trust during an incident. That is the threshold this
document is designed to reach.

---

## What the Retrieval Interface Is Not

Before defining what the interface is, naming what it is not prevents
scope creep that has killed every previous attempt to build this kind
of system.

**It is not a log viewer.** Logs answer what happened in execution terms.
The retrieval interface answers what was declared in governance terms.
These are different questions with different sources and different
surfaces.

**It is not a dashboard.** Dashboards display current state continuously.
The retrieval interface surfaces relevant context at the moment of a
specific governance action or incident investigation. It is query-driven,
not display-driven.

**It is not a search engine.** A search engine returns documents matching
keywords. The retrieval interface returns governed context matching a
specific object, a specific lineage chain, or a specific change event.
The results are structured, attributed, and authorized. Raw text search
against the audit sink is not retrieval in the ONT sense.

**It is not an AI interface.** AI is Layer Three. This document is Layer
Two. The retrieval interface produces structured context that a human can
read and that an AI agent can consume as governed input. It does not
generate recommendations, draft governance declarations, or produce
natural language summaries. It retrieves and structures what is already
recorded.

---

## The Three Queries

The retrieval interface is built around three queries. Each query has a
defined input, a defined output structure, and a defined authorization
requirement. No query returns results the requesting identity is not
authorized to receive.

---

### Query One: Governance History

**The question this answers**

What governance decisions preceded the current state of this object, in
what sequence, with what authority, and what was the declared rationale
for each one?

**When this is needed**

During incident investigation when the current state of a governed object
must be explained in terms of the decisions that produced it. During
compliance audit when an auditor needs the chain from a regulatory
decision to the current running configuration. During onboarding when a
new engineer needs to understand why a domain application is configured
the way it is.

**Input**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| object | reference | yes | none | kind, name, namespace of a governed object present in InfrastructureLineageIndex |
| from | timestamp | no | none | start of time range |
| to | timestamp | no | none | end of time range. If neither from nor to is provided, returns complete history |
| depth | integer | no | full | how many lineage generations to traverse. 1 returns only direct governance events |

**Output structure**

```yaml
GovernanceHistory:
  object:
    kind: CoreBankingService
    name: cbs-production-uk
    namespace: banking
    domain: banking.fintech-core.ontai.dev
    currentVersion: v7
    domainAuthority: core.ontai.dev

  events:
    - version: v7
      timestamp: 2026-03-14T09:23:11Z
      actor: maria.santos@compliance.example.com
      actorRole: compliance-officer
      changeType: governance
      fieldChanged: spec.paymentRails.RTGS.status
      previousValue: active
      newValue: suspended
      rationale: >
        Regulatory instruction ref CBUK-2026-0312 requires suspension
        of RTGS for cross-border transactions pending review.
        Instruction received from Bank of England via compliance
        ticket CT-4471.
      reviewedBy: platform-lead@example.com
      gitRef: abc123def456
      auditEventId: ae-7f3b2c

    - version: v6
      timestamp: 2026-02-28T14:11:44Z
      actor: james.okafor@platform.example.com
      actorRole: platform-engineer
      changeType: governance
      fieldChanged: spec.capabilities.overdrafts.status
      previousValue: inactive
      newValue: active
      rationale: >
        Overdraft capability activated following completion of
        FCA authorisation process ref FCA-AUTH-2026-089.
        Legal sign-off ticket LS-2203.
      reviewedBy: domain-architect@example.com
      gitRef: def456abc789
      auditEventId: ae-6e2a1b

  lineageChain:
    - object: CoreBankingService/cbs-production-uk
      authority: banking.fintech-core.ontai.dev
    - domain: banking.fintech-core.ontai.dev
      authority: fintech-core.ontai.dev
    - domain: fintech-core.ontai.dev
      authority: core.ontai.dev
    - domainCore: core.ontai.dev
      relationship: guardian-provisions-rbacprofile
```

**Authorization**

The requesting identity must hold a PermissionSnapshot that grants read
access to governance history for the target object's domain. Three detail
levels apply.

| Role | Access Level | Rationale Field | Regulatory Flag |
|------|-------------|-----------------|-----------------|
| Compliance officer | Full | Visible | Visible |
| Domain architect | Full | Visible | Visible |
| Platform engineer (authorized domain) | Full | Visible | Visible |
| Platform engineer (other domain) | Operational | Hidden | Hidden |
| Application developer | Dependency | Hidden | Hidden |

The authorization check is performed by Guardian before the query
executes. Fields the requesting identity cannot access are replaced with
a restricted marker rather than omitted. This allows the requesting
identity to know that information exists and to request elevated access
if needed.

---

### Query Two: Dependency Graph

**The question this answers**

What is the complete dependency graph of this object right now, including
all declared upstream dependencies, all declared downstream dependents,
the current binding stability of each connection, and any active
divergence or invalidity conditions on any connection?

**When this is needed**

During incident investigation when the blast radius of a failure must be
computed before action is taken. During change planning when the impact
of a governance change must be understood before it is proposed. During
compliance audit when a regulator needs the complete topology of
connections between systems.

**Input**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| object | reference | yes | none | kind, name, namespace |
| direction | enum | no | both | upstream, downstream, or both |
| depth | integer | no | full | traversal hops from root. 1 returns direct connections only |
| filter | enum | no | none | stable, diverged, degraded, invalid, resolving |

**Output structure**

```yaml
DependencyGraph:
  root:
    kind: CoreBankingService
    name: cbs-production-uk
    domain: banking.fintech-core.ontai.dev
    currentState: desired-state-violation
    violation: savings module not in desired state

  upstream:
    - object: KYCOnboarding/kyc-production
      domain: banking.fintech-core.ontai.dev
      bindingType: SnapshotBinding
      bindingState: stable
      contractVersion: v3
      boundAt: 2026-01-15T08:00:00Z
      purpose: >
        Account activation eligibility verification.
        CBS requires KYC clearance before activating accounts.

    - object: PaymentGateway/pgw-production
      domain: banking.fintech-core.ontai.dev
      bindingType: ContinuousBinding
      bindingState: diverged
      divergedAt: 2026-03-14T09:30:00Z
      divergenceDetail: >
        RTGS rail suspended in CBS spec at v7 but PaymentGateway
        still reports RTGS as active. Divergence detected 30 minutes
        after CBS v7 was applied. Operator escalated. Awaiting
        PaymentGateway reconciliation.
      activeSet: [SEPA, FPS, NEFT]
      suspendedSet: [RTGS, SWIFT]

  downstream:
    - object: ClearingSettlement/cs-production
      domain: trading.fintech-core.ontai.dev
      bindingType: SnapshotBinding
      bindingState: stable
      contractVersion: v3
      boundAt: 2025-11-03T10:00:00Z
      purpose: >
        Cash leg of trade settlement via RTGS for high-value
        transactions and SWIFT for cross-border.
      warning: >
        This downstream dependent holds a SnapshotBinding to
        PaymentGateway at v3 which includes RTGS authorization.
        CBS v7 suspension of RTGS may impact settlement operations.
        SnapshotBinding has not yet entered Diverged state.
        ClearingSettlement operator has not been notified.
        Recommend: trigger cross-domain impact review.

    - object: LoanOriginationSystem/los-production
      domain: banking.fintech-core.ontai.dev
      bindingType: SnapshotBinding
      bindingState: stable
      contractVersion: v4
      boundAt: 2026-02-10T14:00:00Z
      purpose: >
        Account creation verification before loan disbursement.

  crossDomainWarnings:
    - warning: >
        ClearingSettlement in trading domain holds dependency on
        PaymentGateway which is in diverged state relative to CBS v7.
        Cross-domain impact assessment recommended before RTGS
        suspension is fully propagated.
      affectedDomains:
        - banking.fintech-core.ontai.dev
        - trading.fintech-core.ontai.dev
      severity: high
      surfacedAt: 2026-03-14T09:35:00Z
```

**Authorization**

Cross-domain nodes are returned with the detail level authorized by the
requesting identity's PermissionSnapshot for each domain. A platform
engineer authorized in the banking domain but not the trading domain sees
the trading domain nodes with redacted detail and a cross-domain access
restriction notice.

Nodes outside the requesting identity's authorized scope are included in
the graph structure with a restricted marker rather than omitted entirely.
Omitting nodes produces an incomplete graph. An incomplete graph during
incident investigation is more dangerous than a graph with restricted
detail on specific nodes.

---

### Query Three: Change Delta

**The question this answers**

What changed in the governance state of this object or its dependencies
between two points in time, and what was the declared intent behind each
change?

**When this is needed**

During incident investigation when the triggering governance change must
be identified among potentially many changes in a time window. During
post-mortem when the sequence of governance events leading to an incident
must be reconstructed without manual git archaeology. During compliance
audit when a specific time period must be examined for governance changes
with regulatory implications.

**Input**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| object | reference | yes | none | kind, name, namespace |
| from | timestamp | yes | none | start of time range. Required with no default. Unbounded ranges are not permitted |
| to | timestamp | yes | none | end of time range. Required with no default |
| scope | enum | no | object-only | object-only, dependencies, or full-graph |
| filter | enum | no | none | governance, operational, binding-state, operator-event |

**Output structure**

```yaml
ChangeDelta:
  root:
    kind: CoreBankingService
    name: cbs-production-uk
    domain: banking.fintech-core.ontai.dev

  timeRange:
    from: 2026-03-14T08:00:00Z
    to: 2026-03-14T12:00:00Z

  changes:
    - timestamp: 2026-03-14T09:23:11Z
      object: CoreBankingService/cbs-production-uk
      changeType: governance
      layer: one
      field: spec.paymentRails.RTGS.status
      from: active
      to: suspended
      actor: maria.santos@compliance.example.com
      rationale: >
        Regulatory instruction ref CBUK-2026-0312.
      regulatoryImplication: true
      auditEventId: ae-7f3b2c

    - timestamp: 2026-03-14T09:30:00Z
      object: PaymentGateway/pgw-production
      changeType: binding-state
      connection:
        from: CoreBankingService/cbs-production-uk
        to: PaymentGateway/pgw-production
        bindingType: ContinuousBinding
      from: stable
      to: diverged
      divergenceDetail: >
        CBS v7 suspended RTGS but PaymentGateway still active on RTGS.
        Operator escalated at 09:30:22Z.
      auditEventId: ae-7f4a3d

    - timestamp: 2026-03-14T09:30:22Z
      object: CoreBankingService/cbs-production-uk
      changeType: operator-event
      event: desired-state-violation
      check: payment-rail-connectivity
      failureMode: rail-suspended-but-integration-active
      description: >
        RTGS declared suspended in CBS v7 spec but RTGS integration
        point on PaymentGateway is still active. Escalated to
        platform-engineer role. No autonomous action taken.
        Blast radius: RTGS settlement operations via PaymentGateway.
      auditEventId: ae-7f5b4e

    - timestamp: 2026-03-14T09:35:00Z
      object: ClearingSettlement/cs-production
      domain: trading.fintech-core.ontai.dev
      changeType: binding-state
      connection:
        from: ClearingSettlement/cs-production
        to: PaymentGateway/pgw-production
        bindingType: SnapshotBinding
      from: stable
      to: stable
      warning: >
        SnapshotBinding remains stable because PaymentGateway has not
        yet updated its contract. When PaymentGateway reconciles the
        RTGS suspension, this binding will enter Diverged state.
        ClearingSettlement has not been notified. Cross-domain impact
        review recommended.
      auditEventId: ae-7f6c5f

  summary:
    totalChanges: 4
    governanceChanges: 1
    bindingStateChanges: 2
    operatorEvents: 1
    regulatoryImplication: true
    crossDomainImpact: true
    recommendedAction: >
      Cross-domain impact review required for ClearingSettlement in
      trading domain. RTGS suspension in CBS has not yet propagated
      to the trading domain dependency graph. Recommend notifying
      trading domain platform engineer before PaymentGateway
      reconciles the suspension.
```

**Authorization**

The summary section always includes the cross-domain impact flag and
recommended action regardless of authorization level. An operator at 3am
must know that a cross-domain impact exists even if they cannot see the
full detail of the affected domain. Changes in domains outside the
requesting identity's authorization are included with restricted markers,
not omitted.

---

## The Authorization Model

Every query is authorized by Guardian before it executes. The model has
three layers applied in sequence.

### Layer One: Identity Verification

The requesting identity presents a valid credential. The retrieval
interface validates the credential against the current PermissionSnapshot
served by Guardian for the requesting cluster. An identity without a
valid credential receives no response. An error reveals that the query
was understood. No response reveals nothing.

### Layer Two: Domain Authorization

The PermissionSnapshot for the verified identity declares which domains
the identity may query and at what detail level.

| Detail Level | Who Receives It | Fields Included |
|-------------|-----------------|-----------------|
| Full | Compliance officers, domain architects, authorized platform engineers | All fields including rationale, actor identity, regulatory flags |
| Operational | Platform engineers within authorized domain scope | All fields except rationale and regulatory implication flags |
| Dependency | Operators, AI agents | Object existence, binding state, cross-domain impact flags only |

### Layer Three: Result Filtering

After authorization, the query executes against the full dataset. Results
are filtered according to the requesting identity's authorization level
before being returned. Fields the requesting identity cannot access are
replaced with a restricted marker that includes the authorization level
required to see the full field.

This approach allows the requesting identity to know that information
exists and to request elevated access if needed, without revealing the
content of the restricted information.

---

## The Conductor Resolution Handoff

The three queries retrieve stored lineage data. They do not compute new
governance context. Computing new governance context is Conductor's
responsibility.

When a human operator is preparing to make a governance change, they need
more than stored history. They need Conductor's current resolution of the
domain topology. The Conductor resolution handoff has three components.

**Current topology snapshot**

The complete dependency graph as Conductor resolves it at the moment of
the request, computed from live CRD state rather than from stored lineage.
This may differ from Query Two's output if recent changes have not yet
been indexed.

**Proposed change impact assessment**

Given a proposed Layer One field change, Conductor computes the impact on
every object in the dependency graph: which bindings would enter Diverged
state, which cross-domain dependencies would be affected, which operator
escalations would be triggered. This assessment is presented to the human
reviewer before they approve the change, not after.

**Governance sequence recommendation**

Given the proposed change and the computed impact, Conductor recommends
the sequence of governance events that would propagate the change safely.
Not the only valid sequence. The sequence that minimizes the window of
inconsistency between the change in the root object and its propagation
to all declared dependents.

---

## The Minimal Implementation

The retrieval interface is implementable before the full Vortex portal
exists. The minimal implementation has three surfaces.

### CLI Interface

A command line tool that executes the three queries against the
Guardian-authorized audit sink and Conductor resolution endpoint. The
tool authenticates with the same credential used for kubectl. It formats
the output as structured YAML by default and as a human-readable table
with the --human flag.

```bash
# Query One: Governance History
ont history CoreBankingService/cbs-production-uk --depth full

# Query Two: Dependency Graph
ont graph CoreBankingService/cbs-production-uk --direction both

# Query Three: Change Delta
ont delta CoreBankingService/cbs-production-uk \
  --from 2026-03-14T08:00:00Z \
  --to 2026-03-14T12:00:00Z \
  --scope full-graph
```

These three commands are the minimal retrieval interface. When they work
with Guardian authorization enforced, the retrieval layer exists in
production. The full Vortex portal builds on top of this foundation. The
foundation does not require the portal to be useful.

### Alert Integration

When an operator emits an escalation event, the alert payload includes a
pre-computed retrieval context for the affected object. Every escalation
alert carries the following.

- Governance history summary for the affected object covering the last seven days
- Current dependency graph showing all binding states
- Change delta for the last twenty-four hours

An operator receiving this alert at 3am does not need to run queries. The
context is in the alert. This is the integration that closes the 3am gap
Operator Two named. The memory is reliable at 3am when the relevant
context travels with the alert rather than waiting in a filing cabinet
for someone to retrieve it.

### Review Integration

When a pull request modifies a Layer One field, the retrieval interface
produces a governance impact comment on the pull request. The comment
includes the following.

- Governance history of the modified object for context
- Current dependency graph with binding states that the proposed change would affect
- Conductor-computed impact assessment for the specific field change proposed

The human reviewer sees the full governance context of their proposed
change before they approve it. The rationale the human provides when they
approve is stored alongside the governance event. This is the integration
that closes the rationale gap: the why is captured at the moment of
decision because the context that informed the decision is visible at
the moment of decision.

---

## What This Document Commits To

**The three questions have defined specifications.** Each query has
defined inputs, defined output structures, and a defined authorization
model. They can be implemented by a team that was not part of the original
design discussion.

**The authorization model is Guardian-native.** No query returns results
the requesting identity is not authorized to receive. The retrieval
interface is governed from the first query, not bolted onto a governed
system as an afterthought.

**The minimal implementation is a CLI tool with three commands.** When
those three commands work with Guardian authorization enforced, the
retrieval layer exists in production. The full Vortex portal builds on
this foundation. The foundation does not require the portal to be useful.

---

## What This Document Does Not Commit To

**It does not commit to a specific implementation technology.** The three
queries can be implemented against the existing CNPG audit sink, the
InfrastructureLineageIndex, and a Conductor resolution endpoint using any
language and any transport.

**It does not commit to AI integration.** AI consumes the structured
output of the retrieval interface. How it consumes it, what it produces
from that consumption, and how that production is presented to a human
reviewer are Layer Three concerns. This document closes Layer Two.

**It does not commit to a timeline.** It commits to a specification that
makes the timeline estimable. A team that has read this document can
estimate the implementation effort without consulting the original design
discussion. That estimability is the signal that the specification is
complete.

---

## Closing

The three companion documents together constitute the next layer of the
ONT body of work beyond the founding document.

The Brownfield Adoption Playbook gives teams a path from where they are
to where ONT describes.

The Operator Validation Framework gives teams a way to know that the
operators they build correctly encode domain knowledge and handle
production failure modes safely.

The Vortex Retrieval Interface gives the accumulated governance memory an
API that operators can use at 3am without running queries they do not know
how to write.

Together these three documents close the gaps the four operators named.
The founding document describes what ONT is. These three documents
describe how to use it.

The filing cabinet has an API.

---

*ontai.dev | April 2026*
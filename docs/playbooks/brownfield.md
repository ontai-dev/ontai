# ONT Brownfield Adoption Playbook

## Purpose

This document answers the question that every operator who validated
the founding document asked in different words: how do I get from
where I am today to where ONT describes, without breaking production
and without burning out my team?

The founding document says adoption does not require migration. That
is architecturally true. An ONT CRD and operator are a governance
layer placed on top of what already runs. The existing microservices,
Helm charts, ConfigMaps, and secrets do not change.

What the founding document does not say: the work of authoring that
governance layer against a running system you did not design, whose
intent was never formally declared, and whose dependencies are mostly
implicit, is not trivial. This playbook gives that work a concrete
shape.

---

## The Honest Effort Estimate

Before the steps, an honest statement of what this costs.

A simple domain application: one team, one primary function, fewer
than ten microservices, dependencies mostly internal. Effort: two to
four weeks for a team of two. One week of discovery. One week of
schema authorship. One week of operator development. One week of
reconciliation validation.

A moderate domain application: one team, several distinct functional
areas, ten to thirty microservices, dependencies crossing one or two
team boundaries. Effort: six to ten weeks for a team of three. Two
weeks of discovery. Two weeks of schema authorship. Three weeks of
operator development and testing. One week of validation.

A complex domain application: multiple teams, cross-domain
dependencies, thirty or more microservices, regulatory obligations
that require compliance sign-off on the schema. Effort: three to
six months, requires dedicated governance engineering capacity. This
is not a side project.

These estimates assume the platform team has ONT operator authorship
capability. If they do not, add the time to acquire it. The operator
validation framework companion document addresses how to build that
capability.

---

## The Four Stages

---

### Stage One: Discovery

**What this stage produces:** a complete inventory of the governance
layer of the target application, expressed in plain language before
any CRD is written.

**Who does it:** a senior engineer who has operated the application
in production, ideally the person who gets paged when it breaks. Not
the engineer who wrote it. The person who knows what it is supposed
to be.

**Step 1.1: Schedule three sessions with the senior engineer.**

Session one: identity and capabilities. What is this application
in the domain sense? What entity owns it? What modules or functions
does it perform? Which of those modules are authorized versus which
are experimental? Are there jurisdiction-specific constraints on
which modules are active in which environment?

Session two: connections and dependencies. What does this application
formally depend on? Name every upstream dependency, the purpose of
that dependency, and whether the dependency is load-bearing (the
application cannot function without it) or advisory (the application
degrades gracefully without it). What depends on this application?
Name every downstream consumer and what they expect.

Session three: compliance and constraints. What regulatory standards
govern this application? What data residency constraints apply? What
audit retention obligations exist? What schema version is the
application currently running and what was the last migration event?

**Step 1.2: Document the mental checklist.**

Ask the senior engineer: before you touch anything in production,
what do you check? Not the monitoring dashboards. The mental model.
What do you confirm is true before you make a change? Write down
every item in that checklist in plain language. These items are the
desired state declarations that will become Layer One fields.

**Step 1.3: Map the implicit connections.**

Walk through the application's environment variables, network
policies, and external service configurations. For each one ask: is
this a governance fact (who we are authorized to connect to and why)
or an operational fact (how we currently connect)? Mark each one.
The governance facts are Layer One candidates. The operational facts
stay in Layer Two.

**Output:** a Discovery Document. Plain language. No CRD syntax. No
Kubernetes objects. The governance layer of the application expressed
in sentences that a compliance officer and a domain architect can
both read and confirm.

---

### Stage Two: Schema Authorship

**What this stage produces:** a CRD spec that encodes the Discovery
Document as a typed, versioned Kubernetes schema.

**Who does it:** a platform engineer with schema authorship capability,
working with the senior engineer from Stage One as a reviewer.

**Step 2.1: Classify every discovery item.**

Take every item in the Discovery Document and apply the classification
test: if this value changes, does a compliance officer, a security
reviewer, or a domain architect need to know? Yes means Layer One.
No means Layer Two.

Do not classify alone. The senior engineer reviews every
classification. Disagreements about classification are governance
decisions. Record them. They become the rationale for the Layer One
field or the explanation for why the value stays in Layer Two.

**Step 2.2: Design the CRD spec sections.**

ONT CRD specs have a standard structure. Four sections cover the
vast majority of domain applications.

The identity section declares what this application is: the owning
entity, the regulatory jurisdiction, the instance role (primary,
shadow, development), and the domain it belongs to.

The capabilities section declares which functional modules are
authorized, each with an activation status and a contract version.

The connectivity section declares upstream dependencies and
downstream dependents as typed references. Each entry carries the
application kind, the interface version expected, and the binding
stability (SnapshotBinding or ContinuousBinding).

The compliance section declares which regulatory standards apply,
what data residency constraints are active, what audit retention
period is required, and what encryption posture is declared.

Not every application needs all four sections. A simple stateless
service may only need identity and connectivity. Do not add sections
that the Discovery Document does not support.

**Step 2.3: Write the CRD YAML draft.**

Write the CRD spec as a YAML schema with typed fields. Use the
Discovery Document as the source of truth. Every field in the spec
should map to a specific item in the Discovery Document. If a field
cannot be traced to a discovery item, remove it.

**Step 2.4: Review with the compliance team.**

For regulated industries, the CRD spec is a compliance artifact.
The compliance team reviews the Layer One fields to confirm that
the schema captures every obligation they need visible at the
platform layer. This review is not optional. A schema that the
compliance team cannot read is a schema that will not survive the
first audit.

**Output:** a reviewed and approved CRD spec YAML. One file. Ready
for operator authorship.

---

### Stage Three: Operator Authorship

**What this stage produces:** an operator that reads the CRD spec
and reconciles the running system against it.

**Who does it:** a platform engineer with Go experience and
controller-runtime familiarity. Consult the operator validation
framework companion document throughout this stage.

**Step 3.1: Define the reconciliation scope.**

Before writing any code, answer three questions.

What does the operator check on every reconciliation loop? List
every check in plain language, in the order it should run, with
the domain-meaningful failure description for each check if it
fails. This is the specification the code will implement.

What does the operator reconcile autonomously? List every class of
desired state violation the operator is authorized to close without
human action. These are the safe autonomous reconciliation paths.

What does the operator escalate? List every class of desired state
violation the operator cannot or should not close autonomously.
These produce human-action-required events in the audit sink.

This specification is reviewed by the senior engineer before any
code is written. An operator that reconciles outside its authorized
scope is more dangerous than no operator.

**Step 3.2: Implement the reconciliation loop.**

Implement the reconciliation checks in the order specified. Each
check is a discrete function. Each function has a unit test before
the implementation is written. The test defines the expected behavior
against a known fixture. The implementation satisfies the test.

Do not implement more than the specification defines. Every
reconciliation action that is not in the specification is a scope
violation.

**Step 3.3: Implement the event emission.**

Every desired state violation produces an event in the audit sink.
The event carries the domain-meaningful description from the
specification, not a generic Kubernetes error message. The event
is attributed to the operator with the operator's domain identity.
Every autonomous reconciliation action produces an event. Every
escalation produces an event.

If an event cannot be described in domain-meaningful terms, the
reconciliation check that produced it is not yet correctly specified.
Return to the specification before implementing the event.

**Output:** a tested operator implementation with full event emission,
ready for validation.

---

### Stage Four: Reconciliation Validation

**What this stage produces:** confidence that the operator correctly
encodes the domain knowledge from Stage One and handles production
failure modes safely.

**Who does it:** the platform engineer, the senior engineer, and
ideally a second platform engineer who was not involved in authorship.

**Step 4.1: Run the operator against a staging environment.**

Deploy the CRD and operator to a staging environment that mirrors
production as closely as possible. Apply the CRD spec with the
current running state declared as desired state. The operator should
immediately reach a clean reconciliation with no violations.

If the operator produces violations against a correctly running
system, the reconciliation logic has a bug or the desired state
declaration is wrong. Fix before proceeding.

**Step 4.2: Inject known failure conditions.**

For each class of desired state violation in the specification,
inject the condition and verify the operator's response. The
operator must: detect the violation within the reconciliation
interval, produce a domain-meaningful event, attempt autonomous
reconciliation if authorized, or produce an escalation event if not.

The senior engineer verifies that the domain-meaningful descriptions
match their mental model. If a description does not match, the
specification is wrong. Return to Stage Three.

**Step 4.3: Test partial failure and recovery.**

For each autonomous reconciliation action, test partial failure:
the reconciliation begins but the condition it creates is not yet
satisfied at the next reconciliation cycle. The operator must
handle this without producing false positive violations or infinite
retry loops.

Test network partition: the operator cannot reach an external
dependency during the check. The operator must produce a specific
event for unreachable dependency rather than a generic error.

Test version skew: the CRD spec declares a capability version that
the running microservice does not yet implement. The operator must
produce a contract version mismatch violation rather than attempting
to reconcile toward an impossible state.

**Step 4.4: Production readiness review.**

Before deploying to production, the senior engineer signs off on
three statements. First: the CRD spec correctly declares the
governance layer of this application as I understand it. Second:
the operator correctly identifies desired state violations that I
would notice during incident investigation. Third: the operator
does not attempt to reconcile any condition I would want to resolve
manually.

If any statement cannot be signed off, return to the relevant stage.

**Output:** a production-ready CRD and operator, signed off by the
domain senior engineer, with a complete test suite covering normal
operation, known failure conditions, partial failure, and version
skew.

---

## The Quick Win Strategy

Operator Three said the first six to twelve months will feel like
extra work without quick wins. The quick win strategy for brownfield
adoption is to choose the first application deliberately.

The best first application is not the most complex or the most
important. It is the one where the governance layer failure is most
painful and most recent. The application where the last compliance
audit required weeks of manual reconciliation. The application where
the last incident required two hours of archaeology before the team
understood what the system was supposed to do.

That application is the one where Layer One pays off fastest. The
first time the compliance team runs a query against the lineage graph
instead of spending three weeks in email chains, the adoption
argument is made in production, not in a document.

---

## What to Do When the Discovery Reveals No Clear Governance Layer

Some applications genuinely have no governance configuration. They
are pure execution: receive a request, process it, return a result.
No regulatory constraints. No formal connections to other domain
applications. No compliance obligations.

These applications do not need a Layer One CRD. They need better
operational tooling, not governance tooling. Do not force a CRD onto
an application that has nothing to put in it.

The discovery stage will reveal this. If the three sessions with the
senior engineer produce no governance facts that pass the
classification test, the application is not an ONT operator candidate
today. Document that finding and move to the next application.

---

## The Governance Debt Register

Every brownfield system has governance debt: implicit connections,
undeclared constraints, misclassified configuration, missing rationale.
The discovery stage surfaces this debt. Do not try to pay all of it
in Stage Two.

Create a Governance Debt Register for each application. Every
governance fact that was discovered but cannot be captured in the
current CRD spec version goes into the register with a priority and
a target version. The CRD spec evolves over time. The first version
captures the most critical governance facts. Subsequent versions
close the register incrementally.

This prevents the schema authorship stage from becoming paralyzed
by completeness requirements. The first CRD spec does not have to
be perfect. It has to be correct for the fields it declares. Fields
not yet declared belong in the register.

---

# ONT Operator Validation Framework

## Purpose

An operator that confidently reconciles toward a wrong desired state
is more dangerous than no operator at all. The platform will execute
the wrong intent faithfully, continuously, and at scale. This is the
failure mode that Operator Two named as the most dangerous in the
ONT model and the one the founding document does not address directly.

This document answers three questions that every team authoring an
ONT operator must be able to answer before deploying to production.

How do I know the operator correctly encodes the domain knowledge?

How do I know the operator handles production failure modes safely?

How do I know the operator's reconciliation behavior is testable,
reviewable, and improvable over time without breaking what is
already working?

The answers are a framework, not a checklist. A checklist can be
satisfied by going through the motions. This framework produces
artifacts that a senior engineer who did not write the operator can
read and verify independently.

---

## The Three Verification Properties

Every ONT operator must satisfy three verification properties before
it is considered production-ready. These are not quality guidelines.
They are invariants. An operator that cannot demonstrate all three
should not be deployed to a production domain.

**Property One: Specification Completeness**

The operator has a written specification, authored before any code,
that a senior engineer who did not write the operator can read and
verify against their mental model of the domain. The specification
covers every reconciliation check, every autonomous reconciliation
action, every escalation condition, and every domain-meaningful event
the operator emits. No reconciliation behavior exists in code that
is not in the specification.

**Property Two: Behavior Coverage**

The operator has a test suite that covers every path through the
specification. Not every line of code. Every named behavior. Happy
path, known failure conditions, partial failure, recovery, version
skew, and concurrency. A behavior that is in the specification but
not in the test suite is an untested guarantee. Untested guarantees
are not guarantees.

**Property Three: Domain Verification**

The senior engineer who provided the domain knowledge in the
discovery stage has reviewed the specification and the test suite
and confirmed that both correctly represent their understanding of
the domain. Not the code. Not the YAML. The specification and the
tests. Code is an implementation detail. The specification and the
tests are the contract.

---

## Part One: Writing the Operator Specification

The operator specification is the document that precedes the code.
It is written in plain language. It does not contain Go syntax,
Kubernetes API types, or implementation details. It contains behavior
descriptions that a domain expert can verify without reading code.

---

### Section 1.1: Reconciliation Checks

For each check the operator performs on every reconciliation loop,
the specification must answer four questions.

**What condition does this check evaluate?**

Name the condition in domain terms. Not "pod health" but "savings
module availability." Not "service endpoint reachability" but "RTGS
rail connectivity." The condition name must be recognizable to the
senior engineer without explanation.

**What does a passing check look like?**

Describe the state of the running system that satisfies this check.
Be specific. If the check is for savings module availability, what
exactly must be true? Which microservices must be running? At what
replica count? With what health signals? Vague descriptions of
passing conditions produce operators that disagree with the senior
engineer about what healthy means.

**What does a failing check look like?**

Describe the state of the running system that fails this check. Use
the same specificity. A check that can fail in multiple distinct
ways must describe each failure mode separately. A payment rail
connectivity check can fail because the endpoint is unreachable,
because the authentication is rejected, or because the rail is
declared inactive in the spec while the integration point is still
live. Each of these is a distinct failure mode with a distinct
domain meaning and a distinct remediation path.

**What does the operator do when this check fails?**

Name the operator's response in plain language. One of three things.
The operator reconciles autonomously: describe what action it takes
and what it expects the running state to look like after the action.
The operator escalates: describe the event it emits and who is
expected to act on it. The operator tolerates: describe the
conditions under which a failing check does not require action and
the tolerance window before it becomes a violation.

---

### Section 1.2: Autonomous Reconciliation Actions

For each action the operator is authorized to take without human
input, the specification must answer five questions.

**What is this action?**

Name it in domain terms. Not "delete and recreate the deployment"
but "restart the savings module microservice group." Not "patch the
ConfigMap" but "update the payment rail integration configuration."

**What condition triggers this action?**

Reference the reconciliation check from Section 1.1 that produces
this trigger. The trigger must be a specific named failure mode, not
a general category of failure.

**What does the operator do exactly?**

Describe the sequence of Kubernetes operations the operator performs.
Be specific enough that a platform engineer who did not write the
operator can verify that the code matches this description.

**What does the operator expect after the action?**

Describe the running state the operator expects to see at the next
reconciliation cycle. If the expected state is not reached, what
does the operator do? Does it retry, escalate, or enter a waiting
state?

**What is the blast radius of this action?**

Name every component of the running system that this action affects.
If the action restarts a microservice group, name the microservices.
If the action updates a configuration, name every process that reads
that configuration. If the blast radius cannot be fully named, the
action is not safe for autonomous execution.

---

### Section 1.3: Escalation Conditions

For each condition the operator escalates rather than resolves
autonomously, the specification must answer three questions.

**What condition triggers escalation?**

Name it specifically. Reference the failure mode from Section 1.1.

**What event does the operator emit?**

Write the exact domain-meaningful description that appears in the
audit sink. The description must answer: what is wrong, where it
is wrong, what was declared, and what was found. A description that
requires a platform engineer to interpret it before understanding
what it means is not domain-meaningful.

**Who is expected to act on this escalation?**

Name the role. Not a person. The role. Domain architect for contract
version mismatches. Compliance officer for regulatory constraint
violations. Platform engineer for infrastructure failures. The
escalation event must carry enough information for the named role
to act without consulting anyone who was not available when the
event fired.

---

### Section 1.4: The Senior Engineer Sign-Off

After the specification is written, the senior engineer who provided
the domain knowledge reviews it against three statements.

Statement one: every condition named in the reconciliation checks
matches a condition I would evaluate in my head before touching this
system in production.

Statement two: every autonomous action described is an action I
would take without calling anyone if I received an alert for the
triggering condition at 3am.

Statement three: every escalation condition is a condition I would
not resolve without involving another person or team.

If any statement cannot be confirmed, return to the relevant section.
A specification that the senior engineer cannot confirm is a
specification that the operator should not implement.

---

## Part Two: The Behavior Test Suite

The behavior test suite covers every named behavior in the
specification. It does not cover implementation details. A test that
tests a Go function name rather than a domain behavior is an
implementation test. Implementation tests are not behavior tests.
Both may exist, but only behavior tests satisfy Property Two.

---

### Section 2.1: Test Structure

Each behavior test follows a four-part structure.

**Given:** the initial state of the CRD spec and the running system.
Describe both in domain terms. Not "deployment replicas equals zero"
but "savings module microservice group is not running." Not "CRD
field X has value Y" but "savings module is declared active in the
spec."

**When:** the reconciliation event that triggers the behavior.
One event per test. If a behavior requires multiple reconciliation
cycles, write one test per cycle.

**Then:** the expected outcome. Name the domain-meaningful event
emitted, the Kubernetes operations performed, and the state of the
running system after the action.

**And:** the state of the operator at the start of the next
reconciliation cycle. Is it expecting a specific state? Is it in
a waiting condition? Is it ready to proceed to the next check?

---

### Section 2.2: Required Test Categories

Every operator specification produces tests in six categories.
An operator with tests missing from any category is not ready for
production.

**Happy path tests**

One test per reconciliation check that verifies the operator
reaches a clean reconciliation when the running system matches the
declared spec. The happy path test confirms that the operator does
not produce false positive violations against a correctly running
system. This is the most commonly omitted category and the most
important one.

**Known failure mode tests**

One test per named failure mode in the specification. Each test
injects the exact condition described in the failure mode and
verifies the operator's response matches the specification. If the
specification names three distinct failure modes for payment rail
connectivity, there are three distinct failure mode tests.

**Autonomous reconciliation tests**

One test per autonomous action in the specification. Each test
verifies that the operator performs the exact sequence of operations
described, that the blast radius is confined to the components named
in the specification, and that the operator reaches the expected
post-action state within the declared reconciliation interval.

**Escalation tests**

One test per escalation condition. Each test verifies that the
operator emits the exact event described in the specification with
the exact domain-meaningful description. The event text is tested
as a string match, not as a pattern match. A domain-meaningful
description that can drift without breaking the test is not a
reliable escalation signal.

**Partial failure and recovery tests**

For each autonomous reconciliation action, one test covers the case
where the action begins but the expected post-action state is not
reached at the next reconciliation cycle. The operator must either
retry within its authorized scope, escalate, or enter a declared
waiting state. Undefined behavior under partial failure is a
specification gap. Return to the specification before writing this
test.

**Concurrency tests**

For operators that manage multiple instances of the governed
application, one test verifies that simultaneous reconciliation
events on different instances do not interfere. One reconciliation
event should not cause a false positive violation on another
instance. One reconciliation action on one instance should not
affect the running state of another instance.

---

### Section 2.3: Test Fixtures

Each behavior test requires a fixture that represents the initial
state. Fixtures are not minimal stubs. They are domain-representative
states that a senior engineer would recognize as real configurations
of the governed application.

A fixture that uses placeholder values for all fields except the
one being tested is not domain-representative. A fixture that uses
realistic values for identity, capabilities, connectivity, and
compliance teaches the test reader about the domain while verifying
the behavior.

Fixtures are reviewed by the senior engineer alongside the
specification. A fixture that the senior engineer does not recognize
as a realistic configuration of the governed application is a fixture
that will not catch real production failure modes.

---

### Section 2.4: Failure Injection Methods

The test suite uses controlled failure injection to produce the
conditions named in the specification. Three categories of injection
are required.

**State injection:** directly setting the running state of the
test environment to a specific condition. Used for known failure
mode tests. The test sets the running state and verifies the
operator's response. No waiting for natural failure. The condition
is injected precisely.

**Network injection:** simulating network conditions that affect
the operator's ability to reach external dependencies. Used for
connectivity failure mode tests and partial failure tests. The test
intercepts the network call and returns a controlled response:
unreachable, timeout, authentication failure, or protocol error.

**Timing injection:** controlling the reconciliation interval to
verify behavior across multiple reconciliation cycles. Used for
partial failure and recovery tests. The test advances the
reconciliation clock rather than waiting for real time to pass.

---

## Part Three: Production Readiness Criteria

An operator is production-ready when it satisfies all of the
following criteria. Not most of them. All of them.

---

### Criterion 1: Specification Completeness Confirmed

Every behavior in the deployed code has a corresponding entry in
the specification. A code review that finds a reconciliation check
or action not present in the specification is a specification gap.
The specification is updated and the senior engineer re-reviews
before deployment proceeds.

The test for this criterion: ask a platform engineer who did not
write the operator to describe its behavior using only the
specification. Then run the operator against a staging environment
and compare the actual behavior to the description. Discrepancies
are specification gaps or implementation bugs.

---

### Criterion 2: Behavior Test Suite Passing

The complete behavior test suite passes without skipped tests.
A skipped test is an untested guarantee. Untested guarantees
are not guarantees. If a test cannot pass because the behavior
it covers is not yet implemented, the behavior must be removed
from the specification until it is implemented. A specification
that describes behavior the operator does not yet have is a
promise the operator cannot keep.

---

### Criterion 3: Domain Verification Signed Off

The senior engineer has reviewed the final specification and the
behavior test suite and confirmed in writing that both correctly
represent their understanding of the domain. The confirmation is
stored in the operator repository alongside the specification.

The confirmation is not a rubber stamp. It is the senior engineer's
statement that if this operator were running in production, they
would trust it to surface violations they would act on and to
reconcile conditions they would want resolved autonomously. If
that confidence is not present, the operator is not production-ready.

---

### Criterion 4: Failure Mode Coverage Complete

Every failure mode named in the specification has a corresponding
behavior test that injects the exact condition and verifies the
exact response. The test for this criterion: take the list of
failure modes from the specification and the list of failure mode
tests from the test suite and compare them. Every failure mode
must have exactly one test. A failure mode with no test is
untested. A test with no corresponding failure mode in the
specification is an undocumented behavior.

---

### Criterion 5: Blast Radius Documented

Every autonomous reconciliation action has a documented blast radius
that has been verified in the test suite. The blast radius is a
list of every component of the running system that the action
affects. The test verifies that the operator's action does not
affect components outside the documented blast radius.

An operator that affects components outside its documented blast
radius is operating outside its specification. This is a deployment
blocker regardless of whether the out-of-scope effect is beneficial.

---

### Criterion 6: Escalation Events Verified

Every escalation condition has been tested with exact event text
verification. The domain-meaningful description that appears in
the audit sink has been reviewed by the senior engineer and
confirmed as actionable by the named role. An escalation that
requires interpretation before it can be acted on is not an
escalation. It is noise.

---

## Part Four: Operator Evolution and Versioning

An operator written today will need to change. The domain it governs
changes. The regulatory environment changes. The team's understanding
of the domain matures. The operator must be able to evolve without
breaking what is already working.

---

### Section 4.1: CRD Schema Versioning

When the CRD spec requires a new field, a changed field, or a
removed field, the CRD version advances. ONT CRD schemas follow
Kubernetes conventions: v1alpha1 for experimental, v1beta1 for
stabilizing, v1 for stable. A field in a v1 schema may not be
removed without a deprecation cycle.

For every schema version change, the operator must handle instances
of the previous version. If an instance was created at v1beta1 and
the operator has advanced to v1, the operator must be able to
reconcile the v1beta1 instance without error. Schema migration
is the process of moving existing instances from an older version
to a newer version. It is always a human-initiated governance event,
not an operator-autonomous action.

---

### Section 4.2: Adding a Reconciliation Check

When a new reconciliation check is added to the specification, the
following steps apply before the check is deployed to production.

The new check is added to the specification. The senior engineer
reviews the new check against the three statements in Section 1.4.

A behavior test is written for the new check covering the happy
path, every failure mode, and any escalation conditions.

The new check is deployed in observation mode: it evaluates the
condition and emits events but does not take autonomous action and
does not produce violation alerts. The team observes the events
in staging and then in production for at least one full operational
cycle before enabling autonomous action.

After the observation period, the senior engineer confirms that
the events produced match their expectations. Then autonomous
action is enabled.

This process prevents new reconciliation checks from producing
false positive violations in production on the day they are
deployed.

---

### Section 4.3: Removing a Reconciliation Check

A reconciliation check is removed when the domain condition it
covers no longer exists or when the operator's authorization to
reconcile that condition is withdrawn. Removing a check follows
this sequence.

The check is placed in deprecated mode: it continues to evaluate
and emit events but no longer takes autonomous action or produces
violation alerts. The team observes for one full operational cycle
to confirm that nothing depends on the alerts this check was
producing.

The check is removed from the specification. The corresponding
tests are removed. The senior engineer confirms the removal against
the three statements in Section 1.4, specifically confirming that
the condition the check covered is no longer relevant to their
production mental model.

The check is removed from the operator code.

---

### Section 4.4: Operator Decommissioning

When the application an operator governs is decommissioned, the
operator follows a specific lifecycle.

The CRD instance is marked for decommissioning by a human with
governance authority. The operator enters decommission mode: it
stops reconciling and emits a final state event recording the
last known good state of the governed application.

The CRD instance is deleted. The lineage chain records the deletion
event with attribution. The InfrastructureLineageIndex removes the
object from the active graph and archives the lineage record.

The operator deployment is scaled to zero. It is not deleted.
It is retained in the repository with a decommissioned marker.
An operator that was in production governs domain knowledge that
may be relevant to future systems. The specification remains
readable. The tests remain runnable. The institutional knowledge
encoded in the operator is preserved.

---

## Appendix: The Operator Correctness Checklist

*Use this checklist as the final gate before production deployment.
Every item must be checked. An unchecked item is a deployment
blocker.*

Specification is written and reviewed by the senior engineer before
any code was written.

Every reconciliation check in the deployed code appears in the
specification.

Every autonomous action in the deployed code appears in the
specification with a documented blast radius.

Every escalation condition in the deployed code appears in the
specification with exact event text.

The behavior test suite covers all six required test categories.

No tests are skipped.

Every failure mode in the specification has exactly one test.

Every autonomous action test verifies blast radius confinement.

Every escalation test verifies exact event text.

Partial failure and recovery tests pass for every autonomous action.

Concurrency tests pass if the operator manages multiple instances.

The senior engineer has reviewed the specification and the test
suite and confirmed in writing that both correctly represent their
understanding of the domain.

The operator has run in observation mode in staging for at least
one full operational cycle with no unexpected events.

Blast radius documentation is complete and verified.

CRD schema version is correct for the stability level of the fields
it contains.

---


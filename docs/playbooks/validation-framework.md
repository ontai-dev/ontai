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
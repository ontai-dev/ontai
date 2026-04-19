# The Cluster Is the Documentation

## A Companion Document to the ONT Founding Document

*ontai.dev | April 2026*

---

## Where This Document Stands

This document describes both what ONT has built and where it is
going. The distinction matters.

The philosophy is that the cluster is the documentation. Not a
representation of it. The thing itself. That is the destination.

The current state is that ONT has built the lineage chain from
Domain to SubDomain to Service to ExecutionUnit, and the
LineageController writes that chain into every manifest when an
ONT-governed component is deployed or updated. The Lineage Sink
interface is defined. The Document Store and Translation Layer are
the next architectural layers to build.

This document is honest about that sequencing. It describes the
architecture completely so the reader understands both where ONT is
today and what the complete system looks like when finished.

---

## The Oldest Lie in Engineering

Every engineering organization maintains two systems simultaneously.

The first system is the running infrastructure. Pods, deployments,
operators, configuration, the actual behavior of software under
load. This system is precise, machine-executable, and continuously
changing.

The second system is the documentation of the first. Wikis,
runbooks, architecture diagrams, Confluence pages, README files.
This system is human-readable, manually maintained, and begins
drifting from reality the moment it is published.

These two systems have never been the same thing. The running
system does not know the documentation exists. The documentation
does not know the running system has changed. Every organization
that has tried to keep them in sync has discovered the same truth:
documentation is always a lagging representation of a system that
has already moved on.

This is not a discipline failure. It is a structural impossibility.
You cannot keep a representation synchronized with the thing it
represents without a mechanism that makes them the same object.

ONT provides that mechanism. Not by writing better documentation.
By eliminating the need for humans to write documentation at all.

---

## The Precise Architecture

The ONT documentation architecture has five layers. Each layer has
a defined responsibility. No layer does the job of another.

```
ONT Component Deploy or Update
        |
        v
LineageController
  Writes lineage data into manifest
  Domain to SubDomain to Service to ExecutionUnit
        |
        v
Lineage Sink                    <-- current state: interface defined
  Event-driven collector
        |
        v
Document Store                  <-- next layer to build
  Neo4j or PostgreSQL for graph
  MongoDB for document blobs
        |
        v
Translation Layer               <-- follows document store
  NLP fills bounded template slots only
  No freeform generation
        |
        v
Human reads export
Never authors
```

The lineage graph per component follows this shape:

```
Domain
  SubDomain
    Service
      Deployment
        ExecutionUnit (Pod, Job, CronJob)
          Version
            Dependencies
              Timestamp of change
```

Every edge in this graph carries metadata: version, timestamp,
owner, relationship type. The graph is not inferred. It is declared
by the operators that govern each layer.

---

## What the LineageController Does Today

The LineageController in seam-core is the foundation of this
architecture. It is already built and running on the management
cluster.

When any ONT-governed component is deployed or updated, the
LineageController fulfills the lineage field in the manifest.
This field is not an annotation. It is a first-class structural
field reserved by the schema before the LineageController existed.
The schema declares the space. The LineageController fulfills it
as part of the governance contract. The distinction matters: an
annotation is metadata someone adds after the fact. A first-class
lineage field cannot be present without the full chain being valid.
Guardian validates lineage integrity at admission because the field
is structural, not decorative.

The field traces the full path from the Domain authority that
declared this component to the execution unit running it. Every
manifest carries its own provenance.

This is the fact layer. The LineageController has no intelligence.
It observes and writes. It does not interpret what it sees. It does
not generate narrative. It records the typed, versioned lineage
chain as a structured lineage field on the running object.

The InfrastructureLineageIndex in seam-core tracks every governed
object and its lineage reference. It is always current because the
operators continuously reconcile it against the running state. You
can query it programmatically at any time. You can ask: what domain
authority placed this pod here, through what chain of governance
decisions, at what version.

This is the foundation without which the document architecture is
impossible. It is what separates the ONT documentation model from
every documentation tool that came before it: the facts are in the
cluster, written by the system that governs it, not by a human who
observed it after the fact.

---

## The Lineage Sink: Interface Defined

The Lineage Sink is the event-driven collector that receives
lineage events from the LineageController and structures them for
the Document Store. The interface is defined in the ONT
architecture. The implementation is the next engineering milestone.

The Sink receives three categories of event.

A deploy event carries the full lineage field content of a newly
deployed component: the domain path, the service identity, the
execution unit specification, the version, and the timestamp. This
event creates a new document record in the Document Store for this
component.

An update event carries the diff between the previous and current
state of a component: what changed in the spec, what changed in the
lineage field, what the new version is. This event updates the
existing document record and appends a change entry to the
component's version history.

A deletion event carries the lineage field content of a removed
component and the timestamp of removal. This event closes the
document record and archives it with a terminal state marker.

The Sink has no intelligence. It collects structured facts and
routes them to the correct Document Store operation. It does not
decide what a fact means. It does not generate narrative. It is the
plumbing between the fact layer and the storage layer.

---

## The Document Store: Two Databases, Two Roles

The Document Store has two components with distinct roles. They are
not interchangeable.

Neo4j or PostgreSQL holds the lineage graph. It stores the directed
graph of relationships from Domain to ExecutionUnit, with edge
metadata at every hop. This database answers graph queries: what
depends on what, what governs what, what changed in which domain,
what is the full provenance chain of this running pod. It is the
query surface for operational investigation and compliance audit.

MongoDB holds the populated document blobs. Each blob is a
rendered document for a specific component at a specific version,
structured according to the DocumentSchema CRD that governs that
component type. The blob is indexed by a searchDescriptor that
carries the component identity, version, domain, and timestamp.
It is export-ready: a Confluence export, a PDF, a Markdown runbook.

The separation is deliberate. The graph database is for traversal
and query. The document database is for retrieval and export. You
do not query the graph for document blobs. You do not search the
document store for relationship traversal.

---

## The DocumentSchema CRD: Structure Without Content

The DocumentSchema CRD is the governance contract that defines
what a document about a component must contain. It lives in etcd.
It is governed by an operator. It is versioned. It is reconciled.

The CRD does not contain document content. It contains the
structure that content must follow. Each field in the DocumentSchema
declares:

Its name and type. The source of its value: derived from lineage
annotation, derived from spec diff, or flagged as nlp-generated.
Its required status. Its export mapping: which field in a Confluence
template, which section in a Markdown runbook, which cell in a PDF
table this field populates.

A DocumentSchema for a Service component might declare: a name
field derived from the service identity annotation, a domain-path
field derived from the lineage chain, a version field derived from
the deployment spec, a change-summary field marked nlp-generated,
a dependencies field derived from the topology wiring, and an
owner field derived from the RBACProfile.

The DocumentSchema CRD is the boundary between the structured fact
layer and the human-readable output layer. Everything above it is
facts. Everything below it is presentation. The NLP layer sits
exactly at this boundary: it fills the nlp-generated fields and
nothing else.

---

## The Translation Layer: NLP in Bounded Slots

The Translation Layer is where structured facts become human-
readable narrative. It is a tightly scoped NLP operation with a
precisely defined input and output contract.

The input is always structured cluster delta: a spec diff, a
status change, a lineage path, a version transition. Never raw
logs. Never unstructured text. Never inference from unlabeled data.

The scope is always the nlp-generated fields declared in the
DocumentSchema for this component type. The NLP layer fills those
fields and nothing else. It cannot create fields that are not in
the schema. It cannot modify fields that are marked as
lineage-derived. It cannot make architectural decisions or infer
relationships not expressed in the lineage fields.

What the NLP layer produces:

A change-summary field receives a readable sentence that narrates
what the structured diff already says. If the spec diff shows that
the replica count changed from 2 to 4, the change-summary field
receives: "Replica count increased from 2 to 4." Not an
explanation of why. Not an architectural assessment. A narration
of the fact.

A component-purpose field receives a sentence derived from the
component's labels, image name, and lineage context. If the
lineage shows this is a payment-gateway service in the banking
subdomain and the image is tagged as a SWIFT integration service,
the component-purpose field receives a sentence that says exactly
that. It does not infer anything beyond what the labels and lineage
declare.

The NLP layer is not documentation. It is a translator. It takes
typed facts expressed in machine language and renders them in human
language without adding any information that was not already in the
facts.

---

## The Philosophical Boundary

The boundary between the layers is the most important design
decision in this architecture. It must be stated precisely.

The LineageController writes facts. No intelligence. Pure
observation. It does not decide what something means.

The Lineage Sink collects and structures facts. No intelligence.
It routes events to the correct Document Store operation. It does
not decide what to record.

The Document Store persists structured facts and document blobs.
No intelligence. It stores and retrieves. It does not decide what
a document should say.

The Translation Layer fills bounded template slots. Bounded
intelligence. It narrates what the structured input already says.
It does not decide what the component is, what it should do, or
what its relationships mean beyond what the lineage declares.

The Human reads the export. The Human never authors. The document
they receive is always consistent with the cluster state because
it was generated from the same lineage that governs the cluster.

This boundary is enforced architecturally, not by convention. The
nlp-generated field type in DocumentSchema is the only entry point
for NLP output. The NLP layer cannot write to lineage-derived
fields. The operator that governs the Document Store validates this
constraint on every document write. An NLP-generated value in a
lineage-derived field is a schema violation, not a configuration
mistake.

---

## The Dedicated Operator

The documentation architecture requires a dedicated operator in the
Seam family. It inherits from the LineageController pattern and
extends it with document governance.

This operator has three responsibilities.

It watches the LineageController output and routes lineage events
to the Lineage Sink. It does not process the events. It routes
them.

It reconciles DocumentSchema CRDs against the Document Store. When
a new DocumentSchema is deployed or updated, it triggers a
reconciliation of all document blobs for components governed by
that schema. This is how schema changes propagate to existing
documents.

It governs the export pipeline. When a human or an authorized
system requests an export, it retrieves the document blob from
MongoDB, applies the export template for the requested format
(Confluence, PDF, Markdown, runbook), and returns the formatted
artifact. It enforces the export flags declared in the
DocumentSchema: a field marked as export-excluded does not appear
in any export regardless of the requesting system.

This operator has no intelligence. It is infrastructure. The NLP
layer is a service it calls for nlp-generated fields during
document reconciliation. The NLP service is stateless and scoped:
it receives a field definition and a structured cluster delta, and
returns a rendered string. Nothing more.

---

## What This Means for the Operator at 3am

The operator receiving a 3am page does not open a wiki. They do
not search Confluence. They do not ask a colleague what this
service does.

They request a document export for the affected component. The
export is generated from the current Document Store state, which
reflects the current cluster state, because the LineageController
has been writing facts continuously since the component was first
deployed.

The document they receive tells them: what domain authority governs
this component, what subdomain it belongs to, what service it
implements, what version is running, what changed in the last
deployment, what its declared dependencies are, who owns it, and
what the lineage chain is from the domain declaration to the running
pod.

Every fact in that document was written by the cluster as it
happened. No human authored it. No human needs to maintain it.
The only way it can be wrong is if the LineageController has a bug,
which is a testable, fixable property of a software system. Not a
discipline problem. Not a documentation culture problem.

This is the death of the wiki. Not because wikis are bad tools.
Because the information that wikis held imperfectly is now held
perfectly by the cluster, structured by the DocumentSchema CRD,
and accessible through a governed export interface.

---

## Current State: What Is Built, What Is Next

This is where ONT is today.

The LineageController is built and running. It writes lineage
lineage fields in manifests for every ONT-governed component
deployed on the management cluster. The InfrastructureLineageIndex
tracks every governed object. The fact layer is operational.

The Lineage Sink interface is defined in the ONT architecture.
The event categories, the routing contract, and the Document Store
operation mapping are specified. The implementation is the next
engineering milestone after the alpha release of the current five
operators.

The Document Store design is specified. Neo4j or PostgreSQL for
the lineage graph. MongoDB for document blobs. The separation of
concerns is locked. The DocumentSchema CRD structure is defined.

The Translation Layer contract is specified. Input: structured
cluster delta only. Scope: nlp-generated fields in DocumentSchema
only. Output: populated blob per field. No freeform generation.

The export pipeline design is specified. Confluence, PDF, Markdown,
and runbook as output formats. Export flags governed by
DocumentSchema. Human reads. Human never authors.

The dedicated operator is named and located. It inherits from the
LineageController pattern. Its three responsibilities are defined.
Its intelligence boundary is enforced architecturally.

What is not yet built: the Sink implementation, the Document Store
deployment, the Translation Layer integration, the export pipeline,
and the dedicated operator code.

The philosophy is correct. The architecture is sound. The
foundation is running. The build continues.

---

## One Sentence

The cluster does not describe what is true.

The cluster holds what is true, writes it into every manifest as
it happens, structures it according to a governed schema, and
exports it to whatever format the industry already uses.

The human reads. The cluster authors.

---

*ontai.dev | April 2026*
*Apache License 2.0*
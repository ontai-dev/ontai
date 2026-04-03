# ONT Progress Log

## 2026-04-04 — Schema Engineer: Seam Core lineage scaffolding

Schema Engineer session. No reconciliation logic written, no cluster interaction,
no push. Four parts completed in sequence.

**Part 1 — DomainLineageIndex schema (domain-core-schema.md, ontai root):**
Defined the abstract Layer 0 DomainLineageIndex CRD stub at core.ontai.dev. Three
spec sections: rootBinding (rootKind, rootName, rootNamespace, rootUID,
rootObservedGeneration — immutable after admission), descendantRegistry (array of
derived object entries — appended monotonically, never modified), and
policyBindingStatus (domainPolicyRef, domainProfileRef,
policyGenerationAtLastEvaluation, driftDetected). Instantiation contract in §3
defines what every domain layer must preserve or constrain when instantiating.

**Part 2 — InfrastructureLineageIndex schema (seam-core-schema.md, ontai root):**
Defined InfrastructureLineageIndex as the infrastructure domain instantiation of
DomainLineageIndex at infrastructure.ontai.dev. domainPolicyRef and domainProfileRef
constrained to InfrastructurePolicy and InfrastructureProfile by name. creationRationale
constrained to the pkg/lineage.CreationRationale enum. Hand-authored CRD stub YAML
included inline. Deferred implementation items recorded in §6.

**Part 3 — Creation rationale enumeration (seam-core/pkg/lineage/rationale.go):**
Typed CreationRationale string with kubebuilder enum marker. Seven values:
ClusterProvision (Platform), ClusterDecommission (Platform), SecurityEnforcement
(Guardian), PackExecution (Wrapper), VirtualizationFulfillment (Screen — future),
ConductorAssignment (Conductor agent mode), VortexBinding (Vortex — future).

**Part 4 — SealedCausalChain field type (seam-core/pkg/lineage/chain.go):**
SealedCausalChain struct with: rootKind, rootName, rootNamespace, rootUID
(types.UID), creatingOperator (OperatorIdentity{name, version}),
creationRationale (CreationRationale), rootGenerationAtCreation (int64). Code
comment on struct states explicitly that the field is immutable after object
creation and the admission webhook will reject any update that modifies it.

**Files created:**
- ontai/domain-core-schema.md (NEW)
- ontai/seam-core-schema.md (NEW)
- seam-core/api/v1alpha1/groupversion_info.go (NEW — replaces .gitkeep)
- seam-core/api/v1alpha1/infrastructurelineageindex_types.go (NEW)
- seam-core/pkg/lineage/rationale.go (NEW)
- seam-core/pkg/lineage/chain.go (NEW)

**seam-core commit:** d0fba81

**Deferred to LineageController implementation phase:**
- LineageController: CR lifecycle (create, append descendant entries, evaluate
  policy binding). Requires a dedicated Controller Engineer session.
- Admission webhook immutability gate: rejects updates to rootBinding and
  SealedCausalChain fields. Requires a Guardian Controller Engineer session.
- controller-gen wiring for seam-core: CRD YAML above is a hand-authored stub.
  Needs Makefile, controller-gen invocation, and deepcopy generation.
- go mod tidy: seam-core has no go.sum. Must be run before compilation.
- RunnerConfig CRD ownership transfer: governed migration, SC-INV-002.

---

## 2026-04-04 — Governor Directive: Lineage as a First-Class Platform Primitive

Governor documentation session. No code authored, no CRDs modified, no cluster
interaction. Added Section 14 "Governor Directive: Lineage as a First-Class
Platform Primitive" to CLAUDE.md in the ontai root. The directive locks six
architectural decisions covering: sealed causal chain as an immutable structural
spec field (not an annotation); the two-layer schema model with DomainLineageIndex
at ONTAI Domain Core and InfrastructureLineageIndex at Seam Core; controller-exclusive
authorship of LineageIndex instances enforced at admission; the Lineage Index Pattern
(one LineageIndex per root declaration, not per derived object) as a deliberate
scaling decision; creation rationale as a compile-time enumeration in Seam Core's
shared library rather than a free-text field or per-operator registry; and
introduction sequencing (sealed field plus shared library function during stub phase,
LineageController deferred as a distinct implementation milestone). Amendment entry
added to CLAUDE.md amendment history.

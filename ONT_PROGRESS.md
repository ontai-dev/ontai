# ONT Progress Log

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

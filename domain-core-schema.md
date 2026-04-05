# domain-core-schema
> Layer: ONTAI Domain Core (Layer 0)
> API Group: core.ontai.dev
> Status: STUB — abstract definition awaiting domain instantiation
> All domain-level schema engineers read this before defining lineage types.

---

## 1. Layer Identity

ONTAI Domain Core is Layer 0 of the ONTAI schema hierarchy. It owns abstract
type definitions that are not specific to any single domain. No operator
implements this layer directly. Every domain operator instantiates the types
defined here by extending them with domain-specific constraints.

**What lives at Layer 0:**
- `DomainLineageIndex` — the abstract sealed causal chain index type
- Abstract field vocabulary shared across all domain instantiations

**What does NOT live at Layer 0:**
- Reconciliation logic of any kind
- Domain-specific enum constraints on rationale fields
- References to domain-specific CRDs (InfrastructurePolicy, etc.)
- Operator-specific status conditions

**Instantiation model:**
Each domain layer (e.g., infrastructure.ontai.dev at Seam Core) instantiates the
abstract types from this layer, constraining open string fields to domain-specific
enumerations and replacing abstract policy reference fields with typed references
to domain-owned CRDs.

---

## 2. DomainLineageIndex

### 2.1 Purpose

`DomainLineageIndex` is the sealed causal chain index. One instance is created per
root declaration. It is the single authoritative record for the entire derivation
tree rooted at that declaration. Derived objects carry a reference to the root's
lineage anchor; they do not have their own index instances.

**Lineage Index Pattern:**
- One `DomainLineageIndex` per root declaration. Not one per derived object.
- All derived objects (RunnerConfig, Job, OperationResult, PermissionSnapshot, etc.)
  record their derivation back to the root's lineage anchor.
- The index is never replicated per derived object. It is never fan-out.
- This is a deliberate scaling decision: a single TalosCluster with a long
  operational history would otherwise spawn hundreds of index CRs, creating
  reconciliation storms and etcd revision pressure.

**Authorship:**
`DomainLineageIndex` instances are controller-authored exclusively. No human
writes a `DomainLineageIndex` CR. No automation pipeline writes one. The
admission webhook rejects writes from any principal other than the designated
controller service account. Humans may read. They may never write.

**Immutability:**
The `spec.rootBinding` section is immutable after creation. The admission webhook
rejects any UPDATE request that modifies a `rootBinding` field. The
`descendantRegistry` section grows monotonically — entries are appended, never
modified or removed. The `policyBindingStatus` section is updated by the
controller on each reconcile cycle.

### 2.2 CRD Stub

```
# STUB — core.ontai.dev/v1alpha1 DomainLineageIndex
# Layer 0 abstract definition. Not directly deployed. Instantiated by each domain.
# Do not add controller-gen markers or implementation detail to this stub.
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: domainlineageindices.core.ontai.dev
  annotations:
    ontai.dev/layer: "0"
    ontai.dev/status: "stub"
    ontai.dev/abstract: "true"
spec:
  group: core.ontai.dev
  names:
    kind: DomainLineageIndex
    listKind: DomainLineageIndexList
    plural: domainlineageindices
    singular: domainlineageindex
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [rootBinding]
              properties:
                rootBinding:
                  type: object
                  description: >
                    Identifies the root declaration that anchors this lineage index.
                    Immutable after creation. The admission webhook rejects any update
                    that modifies a field in this section.
                  required: [rootKind, rootName, rootNamespace, rootUID, rootObservedGeneration]
                  properties:
                    rootKind:
                      type: string
                      description: Kind of the root declaration (e.g., TalosCluster, PackExecution).
                    rootName:
                      type: string
                      description: Name of the root declaration.
                    rootNamespace:
                      type: string
                      description: Namespace of the root declaration.
                    rootUID:
                      type: string
                      description: UID of the root declaration at time of lineage index creation.
                    rootObservedGeneration:
                      type: integer
                      format: int64
                      description: metadata.generation of the root declaration when this index was created.
                descendantRegistry:
                  type: array
                  description: >
                    Registry of all objects derived from the root declaration.
                    Entries are appended as new derived objects are created.
                    Entries are never modified or removed.
                  items:
                    type: object
                    required: [kind, name, namespace, uid, seamOperator, creationRationale, rootGenerationAtCreation]
                    properties:
                      kind:
                        type: string
                        description: Kind of the derived object.
                      name:
                        type: string
                        description: Name of the derived object.
                      namespace:
                        type: string
                        description: Namespace of the derived object.
                      uid:
                        type: string
                        description: UID of the derived object.
                      seamOperator:
                        type: string
                        description: >
                          Name of the Seam Operator that created this derived object
                          (e.g., platform, guardian, wrapper, conductor).
                      creationRationale:
                        type: string
                        description: >
                          The reason this derived object was created, drawn from a
                          controlled vocabulary. At Layer 0 this is an unconstrained
                          string. Domain instantiations constrain it to a typed enum.
                      rootGenerationAtCreation:
                        type: integer
                        format: int64
                        description: >
                          metadata.generation of the root declaration at the time
                          this derived object was created.
                policyBindingStatus:
                  type: object
                  description: >
                    Records the domain policy and profile bound to the root declaration
                    at the time of last evaluation, and whether drift has been detected.
                  properties:
                    domainPolicyRef:
                      type: string
                      description: >
                        Name of the domain policy bound to the root declaration.
                        Domain instantiations replace this with a typed reference
                        to their domain-specific policy CRD.
                    domainProfileRef:
                      type: string
                      description: >
                        Name of the domain profile bound to the root declaration.
                        Domain instantiations replace this with a typed reference
                        to their domain-specific profile CRD.
                    policyGenerationAtLastEvaluation:
                      type: integer
                      format: int64
                      description: >
                        metadata.generation of the bound domain policy at the time
                        of the last policy evaluation cycle.
                    driftDetected:
                      type: boolean
                      description: >
                        True if the controller detected drift between the expected
                        state derived from the policy and the observed state of
                        derived objects at last evaluation.
            status:
              type: object
              properties:
                conditions:
                  type: array
                  items:
                    type: object
```

### 2.3 Field Reference

#### spec.rootBinding

| Field                  | Type   | Required | Description                                                                  |
|------------------------|--------|----------|------------------------------------------------------------------------------|
| rootKind               | string | yes      | Kind of the root declaration (e.g., TalosCluster, PackExecution)             |
| rootName               | string | yes      | Name of the root declaration                                                 |
| rootNamespace          | string | yes      | Namespace of the root declaration                                            |
| rootUID                | string | yes      | UID of the root declaration at time of index creation                        |
| rootObservedGeneration | int64  | yes      | metadata.generation of the root declaration when the index was created       |

All fields are immutable after admission. Admission webhook rejects any update
that modifies this section.

#### spec.descendantRegistry[]

| Field                   | Type   | Required | Description                                                                  |
|-------------------------|--------|----------|------------------------------------------------------------------------------|
| kind                    | string | yes      | Kind of the derived object                                                   |
| name                    | string | yes      | Name of the derived object                                                   |
| namespace               | string | yes      | Namespace of the derived object                                              |
| uid                     | string | yes      | UID of the derived object                                                    |
| seamOperator            | string | yes      | Name of the Seam Operator that created this derived object                   |
| creationRationale       | string | yes      | Controlled vocabulary value — constrained to enum at domain instantiation    |
| rootGenerationAtCreation| int64  | yes      | Root declaration generation at time derived object was created               |

Entries are appended monotonically. No entry is ever updated or removed.

#### spec.policyBindingStatus

| Field                           | Type    | Required | Description                                                             |
|---------------------------------|---------|----------|-------------------------------------------------------------------------|
| domainPolicyRef                 | string  | no       | Name of domain policy bound to root declaration                         |
| domainProfileRef                | string  | no       | Name of domain profile bound to root declaration                        |
| policyGenerationAtLastEvaluation| int64   | no       | Generation of domain policy at last evaluation                          |
| driftDetected                   | boolean | no       | True if drift detected between expected and observed state at evaluation |

---

## 3. Instantiation Contract

A domain schema that instantiates `DomainLineageIndex` MUST:

1. Use a domain-specific API group (e.g., `infrastructure.ontai.dev`) — never `core.ontai.dev`.
2. Replace `spec.descendantRegistry[].creationRationale` with an enum constraint
   drawn from a compile-time enumeration owned by the domain layer.
3. Replace `spec.policyBindingStatus.domainPolicyRef` with a typed reference to
   the domain-specific policy CRD.
4. Replace `spec.policyBindingStatus.domainProfileRef` with a typed reference to
   the domain-specific profile CRD.
5. Preserve all field names in `spec.rootBinding` without modification.
6. Preserve the Lineage Index Pattern: one instance per root declaration.
7. Preserve the authorship rule: controller-authored exclusively.
8. Preserve the immutability rule: rootBinding fields sealed at admission.

---

## 4. Lineage Provision Standards

### Declaration 1 — core.ontai.dev is a contract and pattern layer exclusively

The `core.ontai.dev` API group is a contract and pattern layer exclusively. It
defines abstract types and structural contracts that every domain layer instantiates.
It never runs controllers against downstream domain CRs. It never watches, lists,
or reconciles objects from any domain below it. This is a permanent, locked boundary
with no exceptions.

**Scope of core.ontai.dev:**
- `DomainLineageIndex` — the universal emission schema contract. Any operator
  family that participates in structured lineage tracking embeds or instantiates
  this type in their domain API group.
- The abstract lineage aggregation ODC (Operator Design Contract) — the structural
  specification that governs how a conforming domain layer must implement its
  concrete lineage aggregation controller. The ODC is owned here as an abstract
  definition; the concrete controller is implemented at the domain layer.
- Abstract field vocabulary shared across all domain instantiations.

**Permanent exclusions from core.ontai.dev — no exceptions:**
- No reconciliation logic of any kind.
- No runtime LineageController instantiated at this layer.
- No CRs from downstream domains (e.g., `infrastructure.ontai.dev`, operator API
  groups) are ever watched, listed, or reconciled from this layer.
- No domain-specific enum constraints on rationale fields.
- No references to domain-specific CRDs.
- No operator-specific status conditions.

**Why this boundary is permanent:**
If core.ontai.dev ever references downstream domain types, it introduces a coupling
dependency that inverts the instantiation hierarchy. Domain layers would no longer
be independently composable. A new operator family adopting `DomainLineageIndex`
would inherit a dependency on every other domain's types. The contract layer must
remain neutral to preserve the portability of the abstract type. This invariant is
locked and requires a Platform Governor constitutional amendment to change.

---

*domain-core-schema — ONTAI Domain Core Layer 0*
*This document is authored and amended by the Platform Governor only.*

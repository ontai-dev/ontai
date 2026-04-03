# seam-core-schema
> API Group: infrastructure.ontai.dev
> Repository: seam-core
> Layer: Seam Core — infrastructure domain instantiation of core.ontai.dev
> All agents read this before touching any seam-core CRD or shared library type.

---

## 1. Domain Boundary

Seam Core is the CRD registry for the Seam platform. It owns cross-operator CRD
definitions that no single operator owns. No reconciliation logic lives here.
No capability engine lives here. Seam Core installs CRD definitions and runs
a schema controller that validates CRD schema versions.

**Seam Core owns:**
- `InfrastructureLineageIndex` — the infrastructure domain instantiation of
  `DomainLineageIndex` from `core.ontai.dev`. Anchors the sealed causal chain
  for every root declaration managed by the Seam platform.
- `RunnerConfig` — produced by Platform and Wrapper, reconciled by Conductor.
  Transfer from conductor shared library is a governed migration (SC-INV-002).
- `InfrastructurePolicy` — produced by humans/guardian, reconciled by Guardian.
- `InfrastructureProfile` — reconciled by Guardian.
- The creation rationale enumeration (`pkg/lineage`) — a compile-time typed
  constant set imported by all Seam Operators.
- The `SealedCausalChain` field type (`pkg/lineage`) — embedded by every
  Seam-managed CRD in its spec.

**What Seam Core does NOT own:**
- Reconciliation loops for any CRD.
- Operator-specific admission logic.
- Runtime or compile-mode execution.

**SC-INV-001** — seam-core owns CRD definitions. Reconcilers live in the operator.
**SC-INV-002** — RunnerConfig CRD transfer is a governed migration.
**SC-INV-003** — seam-core installs before all operators.

---

## 2. Derivation from Domain Core

`InfrastructureLineageIndex` instantiates `DomainLineageIndex` from `core.ontai.dev`
per the domain-core-schema.md instantiation contract (§3). The instantiation rules
applied in this domain are:

| Constraint                        | Domain Core (abstract)                  | Seam Core (infrastructure instantiation)               |
|-----------------------------------|-----------------------------------------|--------------------------------------------------------|
| API group                         | core.ontai.dev                          | infrastructure.ontai.dev                               |
| creationRationale constraint      | unconstrained string                    | enum — `pkg/lineage.CreationRationale` values          |
| domainPolicyRef                   | string (abstract)                       | Name of an `InfrastructurePolicy` CR                   |
| domainProfileRef                  | string (abstract)                       | Name of an `InfrastructureProfile` CR                  |
| rootBinding fields                | as defined — unmodified                 | as defined — unmodified                                |
| Lineage Index Pattern             | one index per root declaration          | one index per root declaration — unchanged             |
| Authorship rule                   | controller-authored exclusively         | controller-authored exclusively — unchanged            |
| Immutability rule                 | rootBinding sealed at admission         | rootBinding sealed at admission — unchanged            |

---

## 3. InfrastructureLineageIndex

### 3.1 Purpose

`InfrastructureLineageIndex` is the concrete sealed causal chain index for all
objects managed by the Seam platform in the infrastructure domain. One instance
is created per root declaration (TalosCluster, PackExecution, etc.) by the
controller responsible for that root declaration type.

All derived objects (RunnerConfig, Job, OperationResult, PermissionSnapshot, etc.)
carry a reference to their root declaration's `InfrastructureLineageIndex`. They
do not carry their own index instances.

The index grows monotonically as new derived objects are created. Entries in
`spec.descendantRegistry` are never modified or removed.

### 3.2 CRD Stub

```
# STUB — infrastructure.ontai.dev/v1alpha1 InfrastructureLineageIndex
# Seam Core infrastructure domain instantiation of core.ontai.dev DomainLineageIndex.
# controller-gen not yet wired for seam-core. Hand-authored stub pending wiring.
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: infrastructurelineageindices.infrastructure.ontai.dev
  annotations:
    ontai.dev/layer: "seam-core"
    ontai.dev/status: "stub"
    ontai.dev/instantiates: "core.ontai.dev/DomainLineageIndex"
spec:
  group: infrastructure.ontai.dev
  names:
    kind: InfrastructureLineageIndex
    listKind: InfrastructureLineageIndexList
    plural: infrastructurelineageindices
    singular: infrastructurelineageindex
    shortNames:
      - ili
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      subresources:
        status: {}
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
                    Immutable after creation. Admission webhook rejects any update
                    that modifies a field in this section.
                  required: [rootKind, rootName, rootNamespace, rootUID, rootObservedGeneration]
                  properties:
                    rootKind:
                      type: string
                    rootName:
                      type: string
                    rootNamespace:
                      type: string
                    rootUID:
                      type: string
                    rootObservedGeneration:
                      type: integer
                      format: int64
                descendantRegistry:
                  type: array
                  description: >
                    Registry of all objects derived from the root declaration.
                    Appended monotonically. Entries are never modified or removed.
                  items:
                    type: object
                    required: [kind, name, namespace, uid, seamOperator, creationRationale, rootGenerationAtCreation]
                    properties:
                      kind:
                        type: string
                      name:
                        type: string
                      namespace:
                        type: string
                      uid:
                        type: string
                      seamOperator:
                        type: string
                        description: Name of the Seam Operator that created this derived object.
                      creationRationale:
                        type: string
                        description: >
                          Reason this derived object was created. Constrained to
                          the pkg/lineage.CreationRationale enumeration.
                        enum:
                          - ClusterProvision
                          - ClusterDecommission
                          - SecurityEnforcement
                          - PackExecution
                          - VirtualizationFulfillment
                          - ConductorAssignment
                          - VortexBinding
                      rootGenerationAtCreation:
                        type: integer
                        format: int64
                policyBindingStatus:
                  type: object
                  description: >
                    Records the InfrastructurePolicy and InfrastructureProfile
                    bound to the root declaration at last evaluation.
                  properties:
                    domainPolicyRef:
                      type: string
                      description: Name of the InfrastructurePolicy bound to the root declaration.
                    domainProfileRef:
                      type: string
                      description: Name of the InfrastructureProfile bound to the root declaration.
                    policyGenerationAtLastEvaluation:
                      type: integer
                      format: int64
                      description: Generation of the InfrastructurePolicy at last evaluation.
                    driftDetected:
                      type: boolean
                      description: True if drift detected between expected and observed state.
            status:
              type: object
              properties:
                conditions:
                  type: array
                  items:
                    type: object
                observedGeneration:
                  type: integer
                  format: int64
```

### 3.3 Field Reference

#### spec.rootBinding (immutable after admission)

| Field                  | Type   | Required | Description                                                             |
|------------------------|--------|----------|-------------------------------------------------------------------------|
| rootKind               | string | yes      | Kind of the root declaration                                            |
| rootName               | string | yes      | Name of the root declaration                                            |
| rootNamespace          | string | yes      | Namespace of the root declaration                                       |
| rootUID                | string | yes      | UID of the root declaration at index creation time                      |
| rootObservedGeneration | int64  | yes      | Root declaration generation when this index was created                 |

#### spec.descendantRegistry[]

| Field                    | Type   | Required | Description                                                            |
|--------------------------|--------|----------|------------------------------------------------------------------------|
| kind                     | string | yes      | Kind of the derived object                                             |
| name                     | string | yes      | Name of the derived object                                             |
| namespace                | string | yes      | Namespace of the derived object                                        |
| uid                      | string | yes      | UID of the derived object                                              |
| seamOperator             | string | yes      | Seam Operator that created this derived object                         |
| creationRationale        | string | yes      | Value from `pkg/lineage.CreationRationale` enum                        |
| rootGenerationAtCreation | int64  | yes      | Root declaration generation when derived object was created            |

#### spec.policyBindingStatus

| Field                            | Type    | Required | Description                                                          |
|----------------------------------|---------|----------|----------------------------------------------------------------------|
| domainPolicyRef                  | string  | no       | Name of the bound InfrastructurePolicy                               |
| domainProfileRef                 | string  | no       | Name of the bound InfrastructureProfile                              |
| policyGenerationAtLastEvaluation | int64   | no       | InfrastructurePolicy generation at last evaluation                   |
| driftDetected                    | boolean | no       | True if drift detected at last evaluation                            |

---

## 4. Creation Rationale Enumeration

Defined in `seam-core/pkg/lineage/rationale.go`. This is a compile-time
`CreationRationale string` type with a controlled vocabulary. All Seam Operators
import this package when populating `SealedCausalChain.CreationRationale`.

New values require a Pull Request to seam-core and Platform Governor review.
Operators do not extend this vocabulary unilaterally.

| Value                    | Operator(s)                  | Meaning                                                           |
|--------------------------|------------------------------|-------------------------------------------------------------------|
| ClusterProvision         | Platform                     | A cluster lifecycle root declaration was created                  |
| ClusterDecommission      | Platform                     | A cluster decommission root declaration was created               |
| SecurityEnforcement      | Guardian                     | A security plane declaration was created                          |
| PackExecution            | Wrapper                      | A pack delivery or execution root declaration was created         |
| VirtualizationFulfillment| Screen (future)              | A virtualization workload root declaration was created            |
| ConductorAssignment      | Conductor (agent mode)       | An operational assignment was created by the Conductor agent      |
| VortexBinding            | Vortex (future)              | A portal policy binding was created                               |

---

## 5. SealedCausalChain Field Type

Defined in `seam-core/pkg/lineage/chain.go`. This is the Go struct that every
Seam-managed CRD embeds in its spec. It is authored once at creation time and
sealed at admission. The admission webhook rejects any update request that
modifies this field after the object is created.

| Field                    | Type                         | Description                                                       |
|--------------------------|------------------------------|-------------------------------------------------------------------|
| rootKind                 | string                       | Kind of the root declaration that caused this object to exist     |
| rootName                 | string                       | Name of the root declaration                                      |
| rootNamespace            | string                       | Namespace of the root declaration                                 |
| rootUID                  | types.UID                    | UID of the root declaration at time of this object's creation     |
| creatingOperator         | OperatorIdentity             | Seam Operator name and version that created this object           |
| creationRationale        | lineage.CreationRationale    | Reason from the controlled vocabulary                             |
| rootGenerationAtCreation | int64                        | Root declaration generation at time this object was created       |

`OperatorIdentity` has two fields: `name` (string) and `version` (string).

---

## 6. Deferred Implementation

The following are out of scope for the stub phase and must not be acted on
without explicit Governor scheduling:

- **LineageController** — the controller that manages `InfrastructureLineageIndex`
  CR lifecycle (create, append descendant entries, evaluate policy binding status).
  Requires a dedicated Controller Engineer session.
- **Admission webhook immutability gate** — the webhook handler that rejects
  updates modifying `spec.rootBinding` or `SealedCausalChain` fields.
  Requires a Guardian Controller Engineer session.
- **RunnerConfig CRD ownership transfer** — from conductor shared library to
  seam-core. SC-INV-002. Requires Governor-scheduled migration session.
- **controller-gen wiring for seam-core** — currently no code generation.
  The InfrastructureLineageIndex CRD YAML above is a hand-authored stub.

---

*seam-core-schema — Seam Core infrastructure domain*
*This document is authored and amended by the Platform Governor and Schema Engineer only.*

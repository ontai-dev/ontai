# CRD Ownership Audit -- T-04c

**Branch:** session/seam-core-audit
**Scope:** guardian, platform, wrapper, conductor repos
**Governing document:** GAP_TO_FILL.md Decision G
**Status:** Complete. Feeds into T-04d (migration session scheduling).

---

## Part 1 -- CRD Ownership Audit

### Decision G restatement

Decision G: All CRD schemas must be owned exclusively by seam-core. Operators own only status subresource field implementations. A CRD whose schema is defined in an operator repo and carries cross-operator contract semantics violates Decision G.

Cross-operator contract: a CRD is a cross-operator contract if two or more operators reference its Go types (via import) or its Kubernetes API group (via unstructured RBAC) for reads or writes. Schema changes in such a CRD affect multiple operators and must be governed at the seam-core layer.

---

### conductor repo (runner.ontai.dev/v1alpha1)

| CRD | Owned by | Reconciled by | Written by | Read by | Cross-operator | Decision G |
|-----|----------|---------------|------------|---------|----------------|------------|
| RunnerConfig | conductor | conductor (agent: status.capabilities, status.capabilityManifest) | platform (creates via unstructured, INV-009), conductor (agent updates status) | wrapper (unstructured reads for PackExecution reconciler), platform (reads for capability confirmation) | YES: platform, conductor, wrapper all access runner.ontai.dev/RunnerConfig | VIOLATION |
| PackReceipt | conductor | conductor (agent writes on pack-deploy completion) | conductor | wrapper (PackExecutionReconciler reads to confirm pack-deploy completion) | YES: conductor writes, wrapper reads | VIOLATION |

**RunnerConfig migration path:** Move Go type definition and CRD schema from conductor/api/ (if present) or conductor/config/crd/ to seam-core (infrastructure.ontai.dev/v1alpha1). Platform imports seam-core instead of conductor. INV-010 already designates the conductor shared library as the RunnerConfig schema authority; Decision G requires the CRD definition to move to seam-core while the shared library package (runnerlib) remains in conductor for the builder/accessor functions.

**PackReceipt migration path:** Move Go type definition from conductor/config/crd/ to seam-core. Wrapper imports seam-core/api/v1alpha1 for PackReceipt reads. Conductor continues to write PackReceipt CRs at runtime.

Note: PackReceipt and PackOperationResult are closely related. PackOperationResult is already in seam-core. The migration session should evaluate whether PackReceipt should be merged into PackOperationResult or kept as a separate type with a distinct lifecycle.

---

### wrapper repo (infra.ontai.dev/v1alpha1)

| CRD | Owned by | Reconciled by | Written by | Read by | Cross-operator | Decision G |
|-----|----------|---------------|------------|---------|----------------|------------|
| ClusterPack | wrapper | wrapper (ClusterPackReconciler) | conductor compiler (compile packbuild path) | platform (TalosCluster conditions reference CiliumPackInstance; ClusterPack is referenced by name), wrapper (reconciler), conductor (compiler imports wrapperv1alpha1.ClusterPack types to emit CR YAML) | YES: conductor imports wrapper/api/v1alpha1 to produce ClusterPack CRs | VIOLATION |
| PackExecution | wrapper | wrapper (PackExecutionReconciler) | wrapper (created by PackExecutionReconciler from ClusterPack targets) | conductor (wrapper generates RunnerConfig from PackExecution fields), wrapper | YES: conductor reads PackExecution via unstructured to populate RunnerConfig spec | VIOLATION |
| PackInstance | wrapper | wrapper (PackInstanceReconciler) | wrapper (PackExecutionReconciler creates on successful pack-deploy) | platform (TalosCluster controller reads PackInstance for Cilium ready condition), wrapper | YES: platform reads PackInstance state for cluster readiness | VIOLATION |

**ClusterPack migration path:** Move Go type definition to seam-core (infrastructure.ontai.dev/v1alpha1). Conductor compiler imports seam-core/api/v1alpha1. Wrapper reconciler imports seam-core/api/v1alpha1. Schema already exists in ontai-schema at v1alpha1/infra/ClusterPack.json -- the seam-core migration adds it to v1alpha1/seam-core/ under the InfrastructureClusterPack title. The ontai-schema infra/ entry remains as an alias or is removed in favour of seam-core/.

**PackExecution migration path:** Move Go type definition to seam-core. Conductor and wrapper both import seam-core/api/v1alpha1. Schema gap: PackExecution has no current entry in ontai-schema -- add it.

**PackInstance migration path:** Move Go type definition to seam-core. Platform, wrapper, and conductor all import seam-core/api/v1alpha1. Schema already exists in ontai-schema at v1alpha1/infra/PackInstance.json -- migrate to seam-core/ layer.

---

### guardian repo (security.ontai.dev/v1alpha1)

| CRD | Owned by | Reconciled by | Written by | Read by | Cross-operator | Decision G |
|-----|----------|---------------|------------|---------|----------------|------------|
| Guardian (singleton) | guardian | guardian (BootstrapController) | guardian | guardian | NO -- internal only | COMPLIANT |
| IdentityBinding | guardian | guardian (IdentityBindingReconciler) | guardian | guardian | NO | COMPLIANT |
| IdentityProvider | guardian | guardian (IdentityProviderReconciler) | guardian | guardian | NO | COMPLIANT |
| PermissionSet | guardian | guardian (PermissionSetReconciler) | guardian | guardian | NO | COMPLIANT |
| PermissionSnapshot | guardian | guardian (PermissionSnapshotReconciler, EPGReconciler) | guardian | conductor (wait-rbac-profile polls via gRPC PermissionService, not direct CR read) | INDIRECT: conductor accesses via PermissionService gRPC, not direct CR | COMPLIANT -- gRPC interface, not CRD contract |
| PermissionSnapshotReceipt | guardian | guardian | guardian | guardian | NO | COMPLIANT |
| RBACPolicy | guardian | guardian (RBACPolicyReconciler) | guardian | guardian | NO | COMPLIANT |
| RBACProfile | guardian | guardian (RBACProfileReconciler) | guardian | conductor (wait-rbac-profile step polls RBACProfile.status.provisioned directly via unstructured) | PARTIAL: conductor reads RBACProfile by name to check provisioned=true | BOUNDARY CASE -- see note |

Note on RBACProfile: conductor reads RBACProfile.status.provisioned via unstructured (runner.ontai.dev group, not security.ontai.dev -- the access is documented in the conductor runnerlib capability). The actual Go type is not imported by conductor; the access is via the Kubernetes API using the raw GVK. This is a weaker form of cross-operator contract than a direct type import. RBACProfile is not a confirmed migration candidate but should be reviewed in the T-04d migration session.

---

### platform repo (platform.ontai.dev/v1alpha1)

| CRD | Owned by | Reconciled by | Written by | Read by | Cross-operator | Decision G |
|-----|----------|---------------|------------|---------|----------------|------------|
| TalosCluster | platform | platform | platform | platform (internal reconciler chain), guardian (SeamMembership references TalosCluster indirectly via cluster name) | INDIRECT: guardian and other ops reference by name, not type | COMPLIANT |
| ClusterMaintenance | platform | platform | platform | platform | NO | COMPLIANT |
| ClusterReset | platform | platform | platform | platform | NO | COMPLIANT |
| EtcdMaintenance | platform | platform | platform | platform | NO | COMPLIANT |
| HardeningProfile | platform | platform | platform | platform | NO | COMPLIANT |
| MaintenanceBundle | platform | platform | platform | platform | NO | COMPLIANT |
| NodeMaintenance | platform | platform | platform | platform | NO | COMPLIANT |
| NodeOperation | platform | platform | platform | platform | NO | COMPLIANT |
| PKIRotation | platform | platform | platform | platform | NO | COMPLIANT |
| UpgradePolicy | platform | platform | platform | platform | NO | COMPLIANT |

All platform CRDs are platform-domain-internal. RunnerConfig references from platform controllers are via unstructured (runner.ontai.dev) using the raw GVK pattern in runnerconfig_cr.go, not via imported types. No Decision G violation.

---

### platform repo -- CAPI provider types (infrastructure.cluster.x-k8s.io/v1alpha1)

| CRD | Owned by | Reconciled by | Decision G |
|-----|----------|---------------|------------|
| SeamInfrastructureCluster | platform (CAPI provider) | platform | NOT APPLICABLE -- CAPI contract governs this group |
| SeamInfrastructureMachine | platform (CAPI provider) | platform | NOT APPLICABLE |
| SeamInfrastructureMachineTemplate | platform (CAPI provider) | platform | NOT APPLICABLE |

CAPI provider types are owned by the provider implementation and governed by the Cluster API contract. The infrastructure.cluster.x-k8s.io API group is not an ONT-owned group. Decision G does not apply.

---

### seam-core repo (infrastructure.ontai.dev/v1alpha1) -- Reference State

| CRD | Owned by | Decision G |
|-----|----------|------------|
| InfrastructureLineageIndex | seam-core | CORRECT -- already at seam-core |
| PackOperationResult | seam-core | CORRECT -- already at seam-core |
| SeamMembership | seam-core | CORRECT -- already at seam-core |

---

### Confirmed migration candidates summary

| CRD | Current repo | Target repo | Priority | Blocking |
|-----|-------------|-------------|----------|---------|
| RunnerConfig | conductor | seam-core | HIGH -- INV-010, T-18 | T-18, T-04d |
| PackReceipt | conductor | seam-core | MEDIUM -- evaluate merge with PackOperationResult | T-04d |
| ClusterPack | wrapper | seam-core | HIGH -- conductor imports wrapper types today | T-04d |
| PackExecution | wrapper | seam-core | HIGH -- needed by T-18 conductor mirror reconstruction | T-18, T-04d |
| PackInstance | wrapper | seam-core | HIGH -- platform imports wrapper types | T-04d |

---

## Part 2 -- Domain Primitive Derivation Mapping

The three-layer derivation chain: Domain Core (core.ontai.dev) -> Application Core (app-core, schema.ontai.dev/v1alpha1/app-core) -> Seam Core (infrastructure.ontai.dev, seam-core repo).

Domain Core primitives available (core.ontai.dev/v1alpha1 from domain-core repo):
- DomainIdentity -- named principal that acts within the domain
- DomainResource -- governed artifact or infrastructure object
- DomainTransaction -- intent-driven operation on a domain resource
- DomainPolicy -- governing rule set
- DomainEvent -- immutable record of something that occurred
- DomainRelationship -- typed connection between two domain objects
- DomainOwnership -- declared custody of a domain resource
- DomainCompliance -- evaluated state against a policy

Application Core schemas available (schema.ontai.dev/v1alpha1/app-core):
- AppAuditPolicy, AppBoundary, AppEventSchema, AppIdentity, AppPolicy, AppProfile, AppResourceProfile, AppTopology, AppWorkflow
- No AppClusterPack, AppPackExecution, AppPackInstance, AppRunnerConfig, AppPackReceipt

### RunnerConfig

RunnerConfig is the schema that encodes what capabilities a Conductor agent has and what operations are requested of it. At the domain level it is a resource (a configuration record) that has identity (named per cluster), governs behaviour (the capabilities field), and carries an execution intent (operator-requested RunnerConfig fields).

The best fit is DomainResource because RunnerConfig is a named, versioned, governed configuration artifact. It is not an event (it is mutable) and it is not a transaction (it is not an operation request -- it is the configuration that enables operations).

| Layer | Type name | Derivation from |
|-------|-----------|----------------|
| Domain Core | DomainResource | abstract governed artifact |
| Application Core | AppRunnerConfig | derives DomainResource, adds capability schema fields |
| Seam Core (target) | InfrastructureRunnerConfig | derives AppRunnerConfig, adds Kubernetes cluster context, Talos version binding |

Gap: AppRunnerConfig does not exist in ontai-schema app-core. InfrastructureRunnerConfig does not exist in ontai-schema seam-core.

### PackReceipt

PackReceipt is an immutable record written by the Conductor execute job after it completes a pack-deploy operation. It records what happened -- which resources were applied, what succeeded, any errors. This maps to DomainEvent.

Note: PackOperationResult (already in seam-core) serves a closely related function. The migration session must determine whether PackReceipt and PackOperationResult are the same concept (merge) or distinct (different lifecycle, different writer, different consumer).

| Layer | Type name | Derivation from |
|-------|-----------|----------------|
| Domain Core | DomainEvent | immutable record of an occurrence |
| Application Core | AppPackEvent | derives DomainEvent, adds pack-deploy context fields |
| Seam Core (target) | InfrastructurePackReceipt | derives AppPackEvent; OR merge into InfrastructurePackOperationResult |

Gap: AppPackEvent does not exist in ontai-schema app-core. The merge-vs-separate decision for InfrastructurePackReceipt vs InfrastructurePackOperationResult must be made in the migration session before the schema PR is raised.

### ClusterPack

ClusterPack is a management cluster record of an immutable compiled OCI artifact for a specific pack version. It is a versioned, content-addressed artifact declaration. This is a DomainResource.

| Layer | Type name | Derivation from |
|-------|-----------|----------------|
| Domain Core | DomainResource | governed artifact |
| Application Core | AppPackDefinition (or AppClusterPack) | derives DomainResource, adds version and registry contract fields |
| Seam Core (target) | InfrastructureClusterPack | derives AppPackDefinition; governs the management-cluster OCI artifact record |

Gap: AppPackDefinition (or AppClusterPack) does not exist in ontai-schema app-core. The infra/ClusterPack.json entry in ontai-schema maps to the current infra.ontai.dev owner (wrapper). The seam-core migration creates seam-core/InfrastructureClusterPack.json and the infra/ClusterPack.json entry becomes deprecated.

### PackExecution

PackExecution represents an intent to execute a pack-deploy for a specific ClusterPack on a target cluster. It is an operator-authored intent object -- the operator creates it to request execution. This is a DomainTransaction (intent-driven operation on a DomainResource).

| Layer | Type name | Derivation from |
|-------|-----------|----------------|
| Domain Core | DomainTransaction | intent-driven operation |
| Application Core | AppPackExecution | derives DomainTransaction, adds pack-deploy execution context |
| Seam Core (target) | InfrastructurePackExecution | derives AppPackExecution, adds management cluster Job binding, RunnerConfig reference |

Gap: AppPackExecution does not exist in ontai-schema app-core. InfrastructurePackExecution does not exist in ontai-schema seam-core. PackExecution has no ontai-schema entry at any layer -- it must be authored in full.

### PackInstance

PackInstance records the delivered state of a ClusterPack on a target cluster. It is the result object that persists after a successful PackExecution. At the domain level it is a DomainResource -- a named, versioned record of a governed artifact installed on a specific cluster.

| Layer | Type name | Derivation from |
|-------|-----------|----------------|
| Domain Core | DomainResource | governed artifact (installed state) |
| Application Core | AppPackInstance | derives DomainResource, adds delivery state and drift fields |
| Seam Core (target) | InfrastructurePackInstance | derives AppPackInstance, adds target cluster reference, OCI digest tracking |

Gap: AppPackInstance does not exist in ontai-schema app-core. The infra/PackInstance.json entry in ontai-schema maps to the current infra.ontai.dev owner (wrapper). The seam-core migration creates seam-core/InfrastructurePackInstance.json and the infra/PackInstance.json entry is deprecated.

---

## Part 3 -- ontai-schema Gap List

This is the input for the ontai-schema PRs to be raised in the T-04d migration session. Items are listed in dependency order.

### Application Core layer -- new entries required

These must be authored and merged into ontai-schema before the seam-core CRD migration begins. The seam-core types derive from these.

| Schema file | Description | Domain primitive | Priority |
|-------------|-------------|-----------------|----------|
| app-core/AppRunnerConfig.json | Capability configuration resource. Extends DomainResource with capability schema fields, version binding, and cluster reference. | DomainResource | HIGH |
| app-core/AppPackDefinition.json | Versioned, content-addressed pack artifact declaration. Extends DomainResource with version, registry reference, and OCI digest fields. | DomainResource | HIGH |
| app-core/AppPackExecution.json | Intent-driven pack-deploy request. Extends DomainTransaction with execution context, target cluster, and RunnerConfig binding. | DomainTransaction | HIGH |
| app-core/AppPackInstance.json | Delivered pack state record. Extends DomainResource with delivery timestamp, drift summary, and deployed resources list. | DomainResource | HIGH |
| app-core/AppPackEvent.json | Immutable pack-deploy completion record. Extends DomainEvent with capability name, status, step results, and failure reason. | DomainEvent | MEDIUM -- pending PackReceipt vs PackOperationResult merge decision |

### Seam Core layer -- new entries required

These replace the infra/ entries once the seam-core CRD migration is complete.

| Schema file | Description | Derives from | Priority |
|-------------|-------------|--------------|----------|
| seam-core/InfrastructureRunnerConfig.json | Kubernetes-deployed capability configuration for a specific cluster. Derives AppRunnerConfig. Adds TalosCluster name binding, conductor image version, and status.capabilities subresource. | AppRunnerConfig | HIGH |
| seam-core/InfrastructureClusterPack.json | Management cluster OCI artifact record. Derives AppPackDefinition. Adds signing status and execution order. | AppPackDefinition | HIGH |
| seam-core/InfrastructurePackExecution.json | Management cluster pack-deploy execution intent. Derives AppPackExecution. Adds Kueue Job binding, status conditions, and progress tracking. | AppPackExecution | HIGH |
| seam-core/InfrastructurePackInstance.json | Target cluster pack installed-state record. Derives AppPackInstance. Adds upgradeDirection and basePackName. | AppPackInstance | HIGH |
| seam-core/InfrastructurePackReceipt.json | Immutable Conductor job completion record. Derives AppPackEvent. Adds job name reference. PENDING: merge decision with PackOperationResult. | AppPackEvent | MEDIUM |

### Seam Core layer -- existing entries to update

| Schema file | Change required |
|-------------|----------------|
| seam-core/PackOperationResult.json | Review against InfrastructurePackReceipt derivation decision. If merged: absorb PackReceipt fields and update description. If kept separate: add x-ont-depends-on reference to InfrastructurePackReceipt. |

### Infra layer -- entries to deprecate after seam-core migration

| Schema file | Action |
|-------------|--------|
| infra/ClusterPack.json | Mark deprecated with x-ont-replaces: seam-core/InfrastructureClusterPack. Remove after all operator imports point to seam-core. |
| infra/PackInstance.json | Mark deprecated with x-ont-replaces: seam-core/InfrastructurePackInstance. Remove after all operator imports point to seam-core. |

### Domain Core layer -- no new entries required

The existing domain-core primitives (DomainResource, DomainTransaction, DomainEvent) cover all migration candidates. No new domain-core primitives need to be authored for this migration.

---

## Outputs for T-04d

The migration session (T-04d) receives the following inputs from this audit:

1. **Confirmed migration candidates:** RunnerConfig, PackReceipt, ClusterPack, PackExecution, PackInstance. All five must be moved to seam-core.

2. **Merge decision required:** PackReceipt vs PackOperationResult -- must be decided at the start of the migration session before any schema PR is raised.

3. **ontai-schema PRs to raise (in order):**
   - PR 1: app-core layer -- AppRunnerConfig, AppPackDefinition, AppPackExecution, AppPackInstance (AppPackEvent pending merge decision)
   - PR 2: seam-core layer -- InfrastructureRunnerConfig, InfrastructureClusterPack, InfrastructurePackExecution, InfrastructurePackInstance (InfrastructurePackReceipt pending merge decision)
   - PR 3: seam-core/PackOperationResult.json update (pending merge decision)
   - PR 4: infra/ deprecation markers for ClusterPack.json and PackInstance.json

4. **Go type migration PRs (after ontai-schema PRs merge, per Decision 11):**
   - seam-core repo: add RunnerConfig, PackReceipt, ClusterPack, PackExecution, PackInstance Go types
   - conductor repo: remove RunnerConfig and PackReceipt Go type definitions, update imports to seam-core
   - wrapper repo: remove ClusterPack, PackExecution, PackInstance Go type definitions, update imports to seam-core
   - platform repo: remove unstructured RunnerConfig workaround (runnerconfig_cr.go), replace with seam-core typed import
   - guardian repo: no changes -- guardian CRDs are compliant

5. **Invariant to satisfy:** SC-INV-002 (seam-core/CLAUDE.md) -- RunnerConfig transfer requires a Governor-scheduled migration session. T-04d pre-authorization covers this requirement.

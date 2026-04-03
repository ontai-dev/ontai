# Seam CRD Registry

Complete CRD inventory across all three layers. Each entry includes: name, layer
classification, owning layer, designated reconciler, type lineage where applicable,
CRD group, and status (live or declared).

---

## ONTAI Domain Core — core.ontai.dev — Declared

| CRD                | Reconciler         | Lineage | Status   |
|--------------------|--------------------|---------|----------|
| DomainPolicy       | ONTAI Domain Core  | —       | Declared |
| DomainProfile      | ONTAI Domain Core  | —       | Declared |
| DomainRelationship | ONTAI Domain Core  | —       | Declared |
| DomainIdentity     | ONTAI Domain Core  | —       | Declared |
| DomainRegistry     | ONTAI Domain Core  | —       | Declared |

---

## Seam Core — infrastructure.ontai.dev — Declared

| CRD                     | Reconciler  | Lineage                                                    | Status   |
|-------------------------|-------------|------------------------------------------------------------|----------|
| InfrastructurePolicy    | Guardian    | DomainPolicy → InfrastructurePolicy                        | Declared |
| InfrastructureProfile   | Guardian    | DomainProfile → InfrastructureProfile                      | Declared |
| RunnerConfig            | Conductor   | Produced by Platform, Wrapper, and future Seam Operators   | Declared |
| PlatformResource        | Seam Core   | —                                                          | Declared |
| PlatformIdentity        | Seam Core   | —                                                          | Declared |
| PlatformPolicy          | Seam Core   | —                                                          | Declared |
| PlatformTransaction     | Seam Core   | —                                                          | Declared |
| PlatformCompliance      | Seam Core   | —                                                          | Declared |
| PlatformOwnership       | Seam Core   | —                                                          | Declared |
| PlatformEvent           | Seam Core   | —                                                          | Declared |
| PlatformRelationship    | Seam Core   | —                                                          | Declared |

---

## Guardian — security.ontai.dev — Live

| CRD                        | Reconciler | Lineage                                                        | Status |
|----------------------------|------------|----------------------------------------------------------------|--------|
| RBACPolicy                 | Guardian   | DomainPolicy → InfrastructurePolicy → RBACPolicy               | Live   |
| RBACProfile                | Guardian   | DomainProfile → InfrastructureProfile → RBACProfile            | Live   |
| PermissionSet              | Guardian   | —                                                              | Live   |
| PermissionSnapshot         | Guardian   | —                                                              | Live   |
| PermissionSnapshotReceipt  | Conductor  | —                                                              | Live   |
| IdentityBinding            | Guardian   | —                                                              | Live   |
| IdentityProvider           | Guardian   | —                                                              | Live   |

---

## Platform — platform.ontai.dev — Live

| CRD                        | Reconciler | Lineage | Status |
|----------------------------|------------|---------|--------|
| TalosCluster               | Platform   | —       | Live   |
| TalosControlPlane          | Platform   | —       | Live   |
| TalosWorkerConfig          | Platform   | —       | Live   |
| SeamInfrastructureCluster  | Platform   | —       | Live   |
| SeamInfrastructureMachine  | Platform   | —       | Live   |
| ClusterAssignment          | Platform   | —       | Live   |
| PlatformTenant             | Platform   | —       | Live   |
| QueueProfile               | Platform   | —       | Live   |
| HardeningProfile           | Platform   | —       | Live   |
| EtcdMaintenance            | Platform   | —       | Live   |
| NodeMaintenance            | Platform   | —       | Live   |
| NodeOperation              | Platform   | —       | Live   |
| UpgradePolicy              | Platform   | —       | Live   |
| ClusterMaintenance         | Platform   | —       | Live   |
| PKIRotation                | Platform   | —       | Live   |
| ClusterReset               | Platform   | —       | Live   |

---

## Wrapper — infra.ontai.dev — Live

| CRD           | Reconciler | Lineage | Status |
|---------------|------------|---------|--------|
| ClusterPack   | Wrapper    | —       | Live   |
| PackExecution | Wrapper    | —       | Live   |
| PackInstance  | Wrapper    | —       | Live   |
| PackReceipt   | Conductor  | —       | Live   |

---

## Conductor — runner.ontai.dev — Live

| CRD              | Reconciler | Lineage                                                                              | Status |
|------------------|------------|--------------------------------------------------------------------------------------|--------|
| ExecutionProfile | Conductor  | InfrastructureProfile specialization declaring authorized RunnerConfig execution categories | Live |
| OperatorManifest | Conductor  | —                                                                                    | Live   |

---

## Screen — virt.ontai.dev — Declared

| CRD         | Reconciler | Lineage | Status   |
|-------------|------------|---------|----------|
| VirtCluster | Screen     | —       | Declared |

---

## Vortex — portal.ontai.dev — Declared

| CRD          | Reconciler | Lineage                                                    | Status   |
|--------------|------------|------------------------------------------------------------|----------|
| PortalPolicy | Vortex     | DomainPolicy → InfrastructurePolicy → PortalPolicy         | Declared |

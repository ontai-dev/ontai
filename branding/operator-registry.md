# Seam Operator Registry

Each entry lists: authoritative name, prior name, type, bounded responsibility,
CRD group, repository name, and deployment order where applicable.

---

## Guardian

**Prior name:** ont-security
**Type:** Deployed operator
**CRD group:** security.ontai.dev
**Repository:** guardian
**Deployment order:** 1 — deploys first

Seam's designated security authority. Reconciles the authorization fabric. Every
other operator waits for its InfrastructureProfile reaching provisioned=true.

Guardian is the only operator with cross-cutting authority — it operates across the
management cluster and influences all target clusters. It is the only operator with
a CNPG dependency. It is the only operator with genuine in-process intelligence
(EPG computation, policy validation, admission webhook).

---

## Platform

**Prior name:** ont-platform
**Type:** Deployed operator
**CRD group:** platform.ontai.dev
**Repository:** platform
**Deployment order:** 9

Owns the complete lifecycle of Talos clusters. Adopts CAPI for target cluster
lifecycle. Uses direct runner Job path for management cluster bootstrap and any
day-two operations CAPI cannot address.

---

## Wrapper

**Prior name:** ont-infra
**Type:** Deployed operator
**CRD group:** infra.ontai.dev
**Repository:** wrapper
**Deployment order:** 10

Watches ClusterPack CRs, verifies execution gates, produces RunnerConfig, submits
pack-deploy Jobs via Kueue.

---

## Conductor

**Prior name:** ont-agent
**Type:** Deployed operator and execute-mode Job runner
**CRD group:** runner.ontai.dev
**Repository:** conductor
**Deployment:** Deployed to ont-system on every cluster

Reconciles RunnerConfig. Executes named capabilities as Kueue Jobs. Runs as
distroless Go binary. No shell. No scripts. No package manager. No
ConfigMap-mounted script execution under any circumstance. This is a hard
constraint, not a preference.

---

## Compiler

**Prior name:** ont-runner
**Type:** Compile-time binary — never deployed to any cluster
**Repository:** conductor (shares repository with Conductor — two binaries from one Go module)
**Image:** debian-slim with helm, kubectl, talosctl, curl, jq, python3, openssl,
and the Compiler binary

Invoked by humans or CI pipelines on workstations. Produces ClusterPack OCI
artifacts and TalosCluster CR YAML from PackBuild spec and ClusterImport spec
respectively.

ClusterImport is a compile-time construct only — it never surfaces as a live CRD
on any cluster.

---

## Seam Core

**Type:** Schema controller
**CRD group:** infrastructure.ontai.dev
**Repository:** seam-core

Owns cross-operator CRD definitions. RunnerConfig definition lives here —
reconciled by Conductor, produced by Platform, Wrapper, and any future Seam
Operators. InfrastructurePolicy and InfrastructureProfile live here, reconciled
by Guardian.

---

## Screen

**Prior name:** ont-virt
**Status:** Declared — not yet implemented
**CRD group:** virt.ontai.dev
**Repository:** screen

Owns KubeVirt integration and VirtCluster. References TalosCluster. Manages
ClusterPack for KubeVirt installation.

---

## Vortex

**Prior name:** ont-portal
**Status:** Declared — not yet implemented
**CRD group:** portal.ontai.dev
**Repository:** vortex

Human and API entry point into the Seam domain fabric.

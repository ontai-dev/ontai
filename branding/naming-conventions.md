# Seam — Naming Conventions and Identity Hierarchy

---

## ONT — Operator Native Thinking

ONT is a philosophy and manifesto. It is not a product. It is not a prefix. It is
not a brand. ONT does not appear in repository names, operator names, CRD groups,
or binary names. It appears in one context only:

> Built on ONT philosophy — Operator Native Thinking.

The five ONT principles are documented in philosophy.md. They govern design
decisions across all Seam components and any future domain built on the ONTAI
Domain Framework.

---

## ONTAI — Domain Framework and Open-Source Organization

ONTAI is the domain framework and open-source organization at ontai.dev.

ONTAI owns **ONTAI Domain Core** — the universal root framework any domain in any
industry can extend. ONTAI Domain Core is domain-agnostic. It is owned by the ONTAI
community and versioned independently.

Three authoritative layer names:

| Name                  | Description                                                              |
|-----------------------|--------------------------------------------------------------------------|
| ONTAI Domain Core     | Domain-agnostic foundation. Owned by the ONTAI community.               |
| Seam Core             | Infrastructure domain instantiation of ONTAI Domain Core. Its own repository. |
| Seam Operators        | Operational controllers, each bounded and sovereign.                     |

Never use: Layer Zero, Layer One, Layer Two, generic controller, or the ont- prefix
in any documentation.

**ODC — Ontai Domain Contract.** The root-level contract carrying the ONTAI imprint
across sovereign domains. ODC replaces all prior references to root domain contracts,
registration contracts, and Layer Zero contracts in any document.

---

## Seam — The Infrastructure Platform

Seam is the infrastructure platform. It is fully open source. There is no enterprise
tier. There is no licensing gate. There is no cluster count limit. Seam is scoped to
Kubernetes-native infrastructure governance on Talos Linux clusters.

Seam is built on ONT philosophy using the ONTAI Domain Framework.

---

## CRD Group Registry

| CRD Group                | Layer              | Notes                                         |
|--------------------------|--------------------|-----------------------------------------------|
| core.ontai.dev           | ONTAI Domain Core  | Domain-agnostic schema                        |
| infrastructure.ontai.dev | Seam Core          | Cross-operator infrastructure schema          |
| security.ontai.dev       | Guardian           | Security plane                                |
| platform.ontai.dev       | Platform           | Cluster and tenant lifecycle                  |
| infra.ontai.dev          | Wrapper            | Pack compile and delivery                     |
| runner.ontai.dev         | Conductor          | Execution contracts                           |
| virt.ontai.dev           | Screen             | Declared, not implemented                     |
| portal.ontai.dev         | Vortex             | Declared, not implemented                     |

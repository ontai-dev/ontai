# ONT — Operator Native Thinking

A philosophy. Not a product name. Not a prefix. Not a brand.

---

## Five Principles

**All infrastructure operations are declarative, versioned, and auditable.**
No operation exists outside a Kubernetes resource. No state change occurs outside
a reconcile loop. Every configuration change is a commit. Every execution produces
an event or condition. Audit is structural, not optional.

**Humans remain in the loop at every production boundary.**
Operators propose. Humans approve. This is not a UX preference — it is an
architectural constraint. Any system that can take production action without human
confirmation is outside the ONT model. AI accelerates. It does not decide.

**Operators own production end to end.**
A platform operator is not a thin wrapper over an API. It carries the entire
lifecycle contract — bootstrap, runtime, day-two operations, and decommission —
and is accountable for the correctness of every state transition within its domain.

**AI accelerates only upstream of human approval.**
AI-assisted tooling, code generation, and infrastructure reasoning are legitimate
upstream contributions. They produce proposals, schemas, and plans. They do not
commit, deploy, or execute. The gate between AI output and production action is
always a human.

**The cluster boundary is the strongest structural independence boundary Kubernetes offers.**
Each cluster is a domain in its own right — its own control plane, its own security
fabric, its own operational lifecycle. Domain isolation is enforced at the cluster
boundary, not at the namespace or label level. Namespace isolation is a convenience.
Cluster isolation is a guarantee.

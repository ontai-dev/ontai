# ONT Platform: Session Context

**Last updated:** May 5, 2026 (session/23 -- test graph, envtest setup)
**Branch:** main
**Author:** Krishna (ontave / ontave@ontave.dev)

---

## Codebase Understanding: graphify is the Source of Truth

CODEBASE.md files have been removed from all repos. The graphify knowledge graph is the authoritative source of codebase understanding for all agents and contributors.

### Production graph (no test files)

**Graph location:** `~/ontai/graphify-out/graph.json`
**Last built:** May 6, 2026 (session/24b) -- 2,785 nodes, 4,382 links, 261 communities
**Source files:** production Go code only; test files excluded via `.graphifyignore`
**Report:** `~/ontai/graphify-out/GRAPH_REPORT.md`

Use this graph for all production codebase queries: reconciler logic, CRD types, capability implementations, shared library structure.

### Test graph (test files only)

**Graph location:** `~/ontai/graphify-tests-out/graph.json`
**Last built:** May 6, 2026 (session/24b) -- 2,274 nodes, 4,950 links
**Source files:** `*_test.go` and `test/` directories across all repos
**Builder script:** `~/ontai/graphify-tests.py` (run with `python graphify-tests.py` from ontai root)

Use this graph when investigating test infrastructure: shared scheme builders, fake clients, helper utilities, test suite structure, e2e skip conditions. Do not query this graph for production code questions.

### How agents must use the graph

Before any implementation or investigation work, query the appropriate graph:

```
/graphify query "<question>" --graph graphify-out/graph.json        # production code
/graphify query "<question>" --graph graphify-tests-out/graph.json  # test code
/graphify explain "<CRD or function name>"
/graphify path "<SourceConcept>" "<TargetConcept>"
```

Do not walk source files to derive understanding that the graph already contains. Source file reads are permitted only to verify a specific invariant or examine implementation detail the graph references by path.

### How to keep the graph current

After every codebase change -- new Go types, new CRDs, changed reconciler logic, updated lab YAML, new docs -- run from `~/ontai`:

```
/graphify --update
```

This re-extracts only changed files and merges them into the existing graph. A codebase change that is not followed by a graph update is treated the same as a failing test: the graph is stale and agents will reason from incorrect state.

The graph update must be included in the same commit or PR that introduced the change. The Governor reviews that `graphify-out/graph.json` is up to date at session close.


## What This File Is

This is the authoritative live state document for the ONT Platform project.
It is updated at the close of every Governor session. It is the first file
any contributor or Claude Code session must read before beginning work.

---

## Repository Map

| Repo | Description | Latest Commit | Status |
|------|-------------|---------------|--------|
| ontai | Root monorepo, GitHub Pages site | main | Active |
| conductor | Compiler + Conductor agent | session/1-governor-init | Published |
| guardian | Trust root, RBAC, audit sink | session/1-governor-init | Published |
| platform | Cluster lifecycle authority | session/1-governor-init | Published |
| wrapper | Pack delivery engine | session/1-governor-init | Published |
| seam-core | Lineage + DSNS controller | session/1-governor-init | Published |
| domain-core | Domain primitive declarations | session/1-governor-init | Published |
| ontai-schema | OpenAPI JSON Schema spec | main | Public, live |

**Schema specification live at:** https://schema.ontai.dev/v1alpha1/index.json

---

## Locked Architectural Decisions

These decisions are locked. No engineer session may reverse them without
an explicit Governor directive.

**Three-image Conductor model (conductor repo, locked April 2026):**
Compiler: debian-slim. GitOps pipeline only. Never deployed to cluster.
Conductor execute mode: debian-slim. Requires shell environment for SOPS,
Helm, and Kustomize. Runs as short-lived Kueue-managed Jobs on the management
cluster only. Target clusters never run execute-mode Jobs.
Conductor agent mode: distroless Go only. Deployed to ont-system on every
cluster. No shell. No scripts. Ever.
The execute image must never be distroless. The agent image must never be
debian-slim. These are architectural invariants, not preferences.

Compiler subcommands: bootstrap, launch, enable, packbuild, maintenance, component, domain.

**Namespace model (locked):**
seam-system: all Seam operator managers, leader election leases.
ont-system: Conductor agent, exists on every cluster.
seam-tenant-{cluster}: one per managed cluster, ClusterPack/PackExecution/PackInstance.

**RunnerConfig lifecycle:**
One RunnerConfig per cluster in ont-system, owned by Platform.
Platform creates on TalosCluster Ready. Conductor publishes 17 capabilities.
Wrapper creates PackExecution directly (no ephemeral RunnerConfig).
TalosCluster deletion is the only event that deletes the RunnerConfig.

**Schema integrity chain (locked):**
DomainRelationship (domain-core) to RBACProfile.domainIdentityRef (guardian)
to InfrastructureLineageIndex.domainRef (seam-core) to SeamMembership
(seam-core CRD, guardian reconciler) to PermissionSnapshot (guardian).

**Schema-First Development Contract (locked April 2026):**
ontai-schema is the authoritative source for all CRD field definitions.
Go type implementations in operator repos are implementations of the schema,
not the source of it.
- Schema changes go to ontai-schema first, before any operator repo implementation.
- Each operator repo CI validates CRD YAML against schema.ontai.dev before merge.
- Implementation PRs adding fields absent from the schema are blocked until the
  schema PR merges first.
This closes the gap between the ONT governance claim (schema is the contract) and
how ONT develops. ONT eats its own cooking at the schema layer from this point forward.

**ONTAR:** Future specification only. NOT IMPLEMENTED. Never present as a
current capability in any document.

**No em dashes anywhere.** No Co-Authored-By git trailers. Apache 2.0 for all repos.

---

## What Is Working End to End (Confirmed)

Management cluster (ccs-mgmt, 5-node Talos, VIP 10.20.0.10):

- TalosCluster import reaches Ready in seconds after talosconfig secret applied
- Platform auto-onboards: RBACPolicy allowedClusters, RBACProfiles targetClusters,
  LocalQueue, target-cluster-kubeconfig
- Guardian CNPG connected, 197+ audit events written, 5 action types
- EPG auto-refreshes stale snapshots (3600s freshness window)
- ClusterPack delivery: all 4 gates clear automatically, Job 1/1 Complete
- PackInstance version field populated (spec.version: v0.1.2)
- DNS records: all 5 types resolve correctly
- Deletion cascade: TalosCluster deletes RunnerConfig + kubeconfig + DNS records

**Bootstrap sequence (manual steps still required):**
1. Apply bootstrap secrets from compiler output
2. Manually create talosconfig secret from ~/.talos/config
3. Apply TalosCluster CR

---

## What Is Not Yet Tested

- ccs-dev tenant cluster onboarding
- PackReceipt on tenant cluster
- Drift detection
- Federation channel (audit forwarding tenant to management)
- CAPI lifecycle path
- IdentityBinding/IdentityProvider e2e with Keycloak/Dex
- SeamMembership on live cluster

---

## Schema Documents Location

Schema docs have been moved from ontai root into each operator repo:

| File | Location |
|------|----------|
| guardian-schema.md | guardian/docs/guardian-schema.md |
| platform-schema.md | platform/docs/platform-schema.md |
| wrapper-schema.md | wrapper/docs/wrapper-schema.md |
| conductor-schema.md | conductor/docs/conductor-schema.md |
| seam-core-schema.md | seam-core/docs/seam-core-schema.md |
| domain-core-schema.md | domain-core/docs/domain-core-schema.md |
| ONTAR.md | conductor/docs/decisions/ontar.md |

---

## Open Source Release State

| Step | Status |
|------|--------|
| ontai-schema published at schema.ontai.dev | Done |
| All 6 repos: README, LICENSE, CONTRIBUTING | Done |
| cmd directories renamed (ont-security to guardian, etc) | Done |
| Founding document updated with living documentation reframing | Done |
| ontai root repo public at ontai-dev/ontai on GitHub | Done |
| ontai.dev GitHub Pages site live (index.html + docs/) | Done |
| schema.ontai.dev redesigned landing page live | Done |
| enable-ccs-mgmt.sh CI script committed to conductor/scripts/ | Done |
| All 6 operator repos made public on ontai-dev GitHub | PENDING |
| Community announcement | PENDING |

---

## Lab Topology

| Component | Value |
|-----------|-------|
| Machine | ThinkPad P-series, 32GB RAM |
| Bridge | talos-br0 at 10.20.0.1/24 |
| Local registry | http://10.20.0.1:5000 |
| ccs-mgmt VIP | 10.20.0.10 |
| DSNS LoadBalancer | 10.20.0.240:53 |
| CNPG | guardian-cnpg in seam-system, 3 instances |
| Kueue ClusterQueue | seam-pack-deploy (6 CPU, 12Gi) |

---

## Governor Locks Pending Before Schema Changes

1. Port 50000 Platform reachability gate
2. RunnerConfig self-maintenance fields and self-operation flag

---

## Key Build Commands

```bash
# Build all images
cd ~/ontai/guardian && make docker-build docker-push IMAGE_REGISTRY=10.20.0.1:5000/ontai-dev TAG=dev
cd ~/ontai/platform && make docker-build docker-push IMAGE_REGISTRY=10.20.0.1:5000/ontai-dev TAG=dev
cd ~/ontai/wrapper && make docker-build docker-push IMAGE_REGISTRY=10.20.0.1:5000/ontai-dev TAG=dev
cd ~/ontai/seam-core && make docker-build docker-push IMAGE_REGISTRY=10.20.0.1:5000/ontai-dev TAG=dev
cd ~/ontai/conductor && make docker-build docker-push IMAGE_REGISTRY=10.20.0.1:5000/ontai-dev TAG=dev

# Compiler binary
cd ~/ontai/conductor && go build -o bin/compiler ./cmd/compiler

# Bootstrap (import mode)
./bin/compiler bootstrap \
  --input ~/ontai/lab/configs/ccs-mgmt/cluster-input.yaml \
  --output ~/ontai/lab/configs/ccs-mgmt/compiled/bootstrap \
  --talosconfig ~/.talos/config

# Enable
./bin/compiler enable \
  --kubeconfig ~/.kube/config \
  --cluster-name ccs-mgmt \
  --registry 10.20.0.1:5000/ontai-dev \
  --dsns-ip 10.20.0.240 \
  --output ~/ontai/lab/configs/ccs-mgmt/compiled/enable
```

---



# ONT Platform: Session Context

**Last updated:** April 24, 2026
**Branch:** main (session/14-bake-lab-patches fully merged)
**Author:** Krishna (ontave / ontave@ontave.dev)

---

## PRIORITY: GAP_TO_FILL.md Work Is Active and Must Finish First

**File:** ~/ontai/GAP_TO_FILL.md
**Status:** Active. Governor-approved. Implementation not yet started.

The tasks listed in GAP_TO_FILL.md (T-01 through T-21 across six phases) represent
the current architectural gap closure work. These tasks are the highest priority in
the project. No new feature work, no backlog items, and no speculative design sessions
may be started until T-01 through T-16 are closed and merged.

T-17 through T-19 are blocked pending TENANT-CLUSTER-E2E.
T-20 through T-21 are blocked pending live cluster access for Day2 scheduling work.
These blocked tasks remain open in BACKLOG.md until their prerequisites are met.

**First gate before any implementation:** WS8b (cert-manager e2e with three-bucket
split) must pass on the management cluster. WS8b is the first live cluster validation.
The full live testing sequence after WS8b is recorded in GAP_TO_FILL.md under "Live
Cluster Testing Sequence" and is authoritative.

**Schema-first ordering is enforced.** Phase 1 schema PRs to ontai-schema must merge
before any Phase 2+ operator implementation PRs are opened. Branch naming convention
for all GAP_TO_FILL work: session/area{N} (one branch per area, one PR per branch).

**Absorption on completion:** When all tasks in a phase are closed and merged, the
closed tasks are absorbed into PROGRESS.md (as closed work items) and BACKLOG.md
(removing the completed entries). GAP_TO_FILL.md is removed and this CONTEXT.md
priority block is deleted at that point. The removal commit closes the gap work cycle.

---

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

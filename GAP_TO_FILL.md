# Seam Platform: Open Work

**Last updated:** 2026-05-02
**Status:** All Phase 1-5 tasks closed. Two design-session items remain. Phase 6 blocked by directive.

---

## Open Items Requiring Design Sessions

**T-23 -- Platform DriftSignal handling for cluster-state drift (platform)**

Current state: `conductor/internal/agent/drift_signal_handler.go` handles pack-drift DriftSignals (retriggers PackExecution). Platform has zero DriftSignal handling. When Conductor detects cluster-state drift (TalosCluster or RunnerConfig delta), the corrective action path is undefined. Design question: does platform watch DriftSignals directly, or does conductor role=management signal platform through a different mechanism? Design session required before implementation.

**T-24 -- TalosCluster deletion cascade per Decision H (platform, conductor)**

Current state: `platform/internal/controller/taloscluster_helpers.go` `handleTalosClusterDeletion()` covers RunnerConfig + Secrets + namespace. Not covered (Decision H order is non-negotiable):
- PackInstance, PackExecution deletion (wrapper layer) before namespace deletion
- RBACProfile, PermissionSet, RBACPolicy, PermissionSnapshot deletion (guardian layer)
- TalosCluster CR deletion last
- mode=bootstrap (infra decommission) vs mode=import (severance only) distinction

Conductor role=tenant on the tenant cluster also becomes orphaned on deletion today. Design session required for the full coordinator sequence.

---

## Phase 6 -- Day2 Scheduling (Blocked -- design session required)

**T-20 -- Day2 operation scheduling with node awareness (platform)**

Day2 ops on management cluster: schedule nodes hosting active seam operator lease pods last. Kueue Jobs must carry node affinity/anti-affinity preventing landing on the node under operation. Blocked: design session.

**T-21 -- CAPI-path Day2 parity verification (platform)**

Verify Day2 operation for CAPI-managed clusters matches the ont-native path. Blocked: design session.

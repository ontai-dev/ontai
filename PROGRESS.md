Session 2 opened. Role: Runner Engineer. Objective: build pkg/runnerlib shared library. All constitutional documents absorbed.
Session 3 opened. Role: Controller Engineer. Objective: RBACPolicy CRD types, validation logic, RBACPolicyReconciler, controller-runtime manager skeleton.
Session 3 closed. All 13 steps complete. 12 unit tests + 5 integration tests green. go vet clean. go build clean. Commit c205ea5.
Session 4 opened. Role: Controller Engineer. Objectives: remaining CRD types (RBACProfile, IdentityBinding, PermissionSet, PermissionSnapshot, PermissionSnapshotReceipt), RBACProfileReconciler with provisioned gate (CS-INV-005), IdentityBindingReconciler validation, EPGReconciler and IdentityBindingReconciler stubs, deferred PermissionSet existence check in RBACPolicyReconciler. All carry-forward findings acknowledged.
Session 5 opened. Role: Controller Engineer. EPG impact trace documented. Objective: EPGReconciler.Reconcile full implementation with ceiling intersection, PermissionSnapshot generation, Drift detection. Delivery deferred to Session 6.
Session 6 opened. Role: Controller Engineer. Redesign acknowledged. Pre-session Governor findings documented (6-A through 6-D). Scope: reconcileDrift wiring, PermissionSnapshotReceipt watch, delivery loop closure. Admission webhook deferred to Session 7. No capability constant implementation this session.
Session 7 opened. Role: Controller Engineer. Objective: admission webhook skeleton — decision.go (pure, no server imports), rbac_handler.go, server.go, webhook config, main.go wiring. 13 unit tests + 7 integration tests. Bootstrap window is TODO(session-8). CS-INV-001 and CS-INV-004 closed on management cluster.
Session 7 closed. All gates complete. 92 unit tests + 26 integration tests green. go vet clean. go build clean. Root cause fixed: ValidatingWebhookConfiguration YAML had webhooks under wrong `spec.` prefix. Metrics port conflict fixed across all integration test suites. Commit 8324c0b.
Session 8 opened. Role: Controller Engineer. Objective: bootstrap RBAC window — close TODO(session-8) in decision.go, implement INV-020 and CS-INV-004.
Session 8 closed. Bootstrap RBAC window implemented and verified. Commit 52e1bb6.
Session 9 opened. Role: Schema Engineer. Objective: wire controller-gen, replace handwritten CRD YAML and zz_generated.deepcopy.go, validate equivalence. Finding F-S3 to close.
Session 9 closed. controller-gen wired. zz_generated.deepcopy.go replaced (780 lines generated, 791 handwritten). All 6 CRD YAML files replaced with generated output — structural schema unchanged. Build clean, 21 unit tests pass. Open sub-finding: PermissionRule.Verbs enum constraint in handwritten CRD cannot be expressed as field-level marker on []string in controller-gen v0.16.1; requires typed Verb string — Controller Engineer session. F-S3 closed. Commit e7a401b.
Session 10 opened. Role: Controller Engineer. Objectives: fix PermissionRule.Verbs (F-S3C), implement IdentityProvider reconciler.
Session 10 closed. F-S3C closed. IdentityProvider reconciler implemented. Build clean, all unit tests pass. Commit 5fe5952.
Governor session: CAPI adoption cross-document alignment complete. Seven documents amended. Path B ruling recorded as authoritative resolution for management cluster lifecycle under CAPI adoption. Six capability constants confirmed retained and not orphaned. INV-013 amended with named reconciler exceptions. guardian AGENTS.md intake scope expanded to include CAPI providers. Orphaned-constant open finding closed. INV-013 amendment open finding closed.
Governor session (2026-04-01): pack-compile misclassification fixed across four documents. CapabilityPackCompile separated into compile-mode section in constants.go. conductor-schema.md Section 9 incorrect Note on pack-compile removed; Section 6 table pack-compile row corrected. PROGRESS.md Finding 6-A Option B withdrawn; closed with correct resolution. Session 2 Capability Reference table pack-compile row updated. BACKLOG.md PackBuild controller and PackBuildReconciler items marked REMOVED.

# ONT Platform Progress
## Platform State
Status: Foundation in progress. Shared library complete. guardian CRD surface complete. Five reconcilers operational (RBACPolicy, RBACProfile, IdentityBinding, EPG, IdentityProvider). EPG computation with ceiling intersection verified. PermissionSnapshot generation live. Drift detection loop closed. Admission webhook operational — CS-INV-001 enforced. Bootstrap RBAC window implemented — INV-020 and CS-INV-004 closed. controller-gen wired — F-S3 closed. Verb enum constraint restored — F-S3C closed.
Current Phase: Phase 1 — Development
Last Session: Session 10 — Controller Engineer, Verb enum fix, IdentityProvider reconciler
Next Session: PermissionSet reconciler (ProfileReferenceCount), PermissionService gRPC, or IdentityBinding identity trust methods (PREREQUISITE: IdentityProvider now implemented — unblocked)

## Session 10 Exit State

**Commit:** 5fe5952 (guardian, branch session/1-governor-init)
**Message:** session/10: Verb enum fix (F-S3C) and IdentityProvider reconciler

**Part 1 — Verb enum (F-S3C closed):**
- Added typed `Verb string` to `permissionset_types.go` with `+kubebuilder:validation:Enum` and eight `Verb*` constants
- Changed `PermissionRule.Verbs` from `[]string` to `[]Verb`
- Updated `intersection.go`: `unionVerbSets` converts `Verb` to `string`; added `verbsToStrings` helper; updated `IntersectWithCeiling` call site
- Updated `permissionset_validation.go`: cast at `validVerbs` map lookup
- Updated all affected test files: added `toVerbs` helper in epg tests; updated permissionset unit tests and three integration test files
- Regenerated `zz_generated.deepcopy.go` and `permissionsets` CRD YAML; enum constraint now present in generated CRD `items` schema

**Part 2 — IdentityProvider reconciler:**
- `api/v1alpha1/identityprovider_types.go`: `IdentityProvider` CRD with `IdentityProviderType` enum (oidc/pki/token), `IdentityProviderSpec` (Type, IssuerURL, CABundle, TokenSigningKey, AllowedAudiences, ValidationRules), `IdentityProviderStatus` with conditions, condition and reason constants
- `internal/controller/identityprovider_validation.go`: pure structural validation; type-specific required field checks; all-failures collection model
- `internal/controller/identityprovider_controller.go`: reconciler with structural validation → Valid condition; OIDC reachability check via injectable `HTTPDoer` → Reachable condition; EPG recompute annotation signal on success
- `internal/controller/epg_controller.go`: IdentityProvider added to annotation-filtered watch and `clearAnnotations`; RBAC marker added
- `cmd/ont-security/main.go`: `IdentityProviderReconciler` wired before EPGReconciler
- Generated `security.ontai.dev_identityproviders.yaml` CRD (7 CRDs total)
- `test/unit/controller/identityprovider_validation_test.go`: 8 unit tests covering all three types, missing required fields, wrong field for type, unknown type defense-in-depth, optional fields pass-through

**Test counts:** 3 unit test packages passing (controller, epg, webhook). Build clean.

**Findings closed:**
- F-S3C: PermissionRule.Verbs enum constraint restored in generated CRD via typed Verb string.

**Prerequisite unblocked:**
- BACKLOG item "IdentityProvider reconciler — PREREQUISITE before IdentityBinding identity trust methods" is now satisfied. IdentityBinding identity trust method implementation is unblocked.

## Session 9 Exit State

**Commit:** e7a401b (guardian, branch session/1-governor-init)
**Message:** session/schema: guardian — wire controller-gen, replace handwritten CRD YAML and deepcopy

**Modified files:**
- api/v1alpha1/groupversion_info.go — added `+groupName=security.ontai.dev` and `+kubebuilder:object:generate=true` package-level markers; required for correct controller-gen v0.16.1 behaviour
- api/v1alpha1/zz_generated.deepcopy.go — replaced handwritten (791 lines) with generated (780 lines); all types covered alphabetically; all pointer/slice/map fields deep-copied correctly
- config/crd/*.yaml (all 6) — replaced handwritten CRD YAML with generated; structural schema identical; generated files add version annotation and full field descriptions from Go doc comments
- Makefile — `generate` target now invokes controller-gen for both object (deepcopy) and crd; `generate-deepcopy` and `generate-crd` available as discrete targets

**Finding F-S3 closed.** controller-gen is now the authoritative generator for deepcopy and CRD YAML.

**Open sub-finding (logged for Controller Engineer session):**
- `PermissionRule.Verbs []string` had an enum constraint (`get, list, watch, create, update, patch, delete, deletecollection`) in the handwritten CRD YAML.
- This cannot be expressed as a field-level marker on `[]string` in controller-gen v0.16.1 — the `+kubebuilder:validation:items:Enum` marker crashes the generator.
- Correct fix: define a typed `Verb string` with `+kubebuilder:validation:Enum=...` and change field to `[]Verb`. This is a non-trivial API type change requiring a Controller Engineer session.
- Until fixed, the generated CRD allows any string in the Verbs list (no enum validation at the API server level). Validation in the controller remains effective.

**Test counts:** 21 webhook unit tests + all prior unit tests passing. Build clean.

**Invariants closed this session:**
- F-S3: controller-gen wired; handwritten CRD YAML and deepcopy eliminated.

**F-S3B note:** KUBEBUILDER_ASSETS must still be set manually before integration tests. Infrastructure note, not a code issue.

## Session 8 Exit State

**Commit:** 52e1bb6 (guardian, branch session/1-governor-init)
**Message:** session/8: bootstrap RBAC window — INV-020, CS-INV-004

**Modified files:**
- internal/webhook/decision.go — `BootstrapWindow` type added (sync/atomic.Bool, starts open). `BootstrapWindowOpen bool` added to `AdmissionRequest`. `EvaluateAdmission` step 2 implemented: when window is open, intercepted RBAC admitted unconditionally. TODO(session-8) removed.
- internal/webhook/rbac_handler.go — `RBACAdmissionHandler` holds `*BootstrapWindow`, reads it per request into `AdmissionRequest.BootstrapWindowOpen`.
- internal/webhook/server.go — `Register(window *BootstrapWindow)` now accepts the window, passes it to the handler, then permanently closes it after registration. This is the INV-020 close event.
- cmd/ont-security/main.go — creates `NewBootstrapWindow()`, passes to `Register()`.
- test/unit/webhook/decision_test.go — 9 new tests (13–21): BootstrapWindow state transitions (starts open, close is permanent, idempotent), EvaluateAdmission with window open for all intercepted kinds, EvaluateAdmission with window closed confirms normal enforcement. Removed `TestDecisionGo_BootstrapWindowStub_Present`.
- test/integration/webhook/rbac_webhook_test.go — TestMain updated for new `Register(window)` signature.

**Invariants closed:**
- INV-020: bootstrap RBAC window named, documented, bounded. Closes permanently in `Register()`.
- CS-INV-004: window has definite close — on first successful webhook registration.

**Test counts:** 21 webhook unit tests passing (was 13). All prior unit and integration tests unaffected.

**TODO items remaining in code:**
- CNPG two-phase boot sequence (future session)
- PermissionSet reconciler (ProfileReferenceCount maintenance)
- PermissionService gRPC server (4 operations)
- IdentityProvider reconciler (prerequisite before identity trust methods in IdentityBinding)

## Session 7 Exit State

**Commit:** 8324c0b (guardian, branch session/1-governor-init)
**Message:** session/7: admission webhook — decision.go, rbac_handler.go, server.go, webhook config, main.go wiring, 13 unit + 7 integration tests

**New files created:**
- internal/webhook/decision.go — EvaluateAdmission pure function, annotation constants, InterceptedKinds, AdmissionRequest/Decision types. TODO(session-8) bootstrap window stub present. No controller-runtime imports (safe for conductor reuse).
- internal/webhook/rbac_handler.go — RBACAdmissionHandler (admission.Handler), raw JSON unmarshal for annotation extraction
- internal/webhook/server.go — AdmissionWebhookServer, WebhookPath constant, Register() method
- config/webhook/validating-webhook-configuration.yaml — ValidatingWebhookConfiguration (top-level webhooks, not spec.webhooks)
- test/unit/webhook/decision_test.go — 13 unit tests for EvaluateAdmission
- test/integration/webhook/rbac_webhook_test.go — 7 integration tests via envtest

**Modified files:**
- cmd/guardian/main.go — --webhook-port flag, webhook server registered before manager.Start
- test/integration/controller/rbacpolicy_controller_test.go — metrics disabled (port conflict fix)
- test/integration/epg/epg_reconciler_test.go — metrics disabled (port conflict fix)

**Bug fixed:** ValidatingWebhookConfiguration YAML used `spec.webhooks` (wrong). The type has `webhooks` at the top level. envtest parsed successfully but the webhooks array was empty. Fixed by removing the `spec:` wrapper.

**Test counts:** 92 unit tests passing, 26 integration tests passing (18 controller + 1 EPG + 7 webhook)

**TODO items remaining in code:**
- Bootstrap RBAC window (TODO(session-8)) — CS-INV-004, INV-020
- CNPG two-phase boot sequence (future session)
- PermissionSet reconciler (ProfileReferenceCount maintenance)
- PermissionService gRPC server

## Session 6 Redesign Acknowledgement

Architectural redesign absorbed (2026-03-30). Key changes confirmed:
1. Two-binary model: conductor (compile, debian, never deployed) and conductor
   (execute+agent, distroless, deployed everywhere). INV-022, INV-023, INV-024.
2. All images on all clusters are distroless. INV-022.
3. No execute-mode Jobs on target clusters. Management cluster Jobs only. INV-022.
4. PackBuild is a local spec file, not a cluster CRD. No PackBuildController.
   No pack-compile Kueue Job on the management cluster. wrapper-design.md Section 9.
5. PermissionSnapshot signing: EPGReconciler generates PermissionSnapshot, management
   cluster conductor signs it. EPGReconciler does not sign. guardian-design.md Section 6.
6. PermissionSnapshotReceipt managed by target cluster conductor, not a separate
   guardian agent. guardian-schema.md Section 8.
7. Community tier: 5 target clusters, management cluster never counted. INV-025.
8. License enforcement in conductor agent mode only. conductor has no license logic.

Open findings evaluated for continued relevance under the 2026-03-30 redesign:
- [Session 1] Repository layout (subdirectories) — still valid, unaffected by redesign.
- [Session 2] Community tier cluster limit conflict — RESOLVED by redesign. INV-025
  authoritative: 5 target clusters, management cluster excluded. Carry as CLOSED.
- [Session 3] CRD YAML handwritten, controller-gen not wired — still valid, growing risk.
- [Session 3] DeepCopy manually written — still valid, same note.
- [Session 3] KUBEBUILDER_ASSETS env var — still valid, infrastructure note.

## Session 6 Pre-Session Governor Findings

**Finding 6-A — CapabilityPackCompile constant is architecturally ambiguous:** CLOSED (2026-04-01).
The Session 2 capability table recorded CapabilityPackCompile ("pack-compile") as a Kueue
Job executor-mode capability. The 2026-03-30 redesign removes compile mode from all clusters.

~~Governor Resolution Option B~~ — WITHDRAWN. Option B (validation-only conductor Job) was
an interim ruling and is superseded by the correct final resolution:

**Final Resolution:** pack-compile is an conductor compile mode capability. PackBuild is a
local spec file on the workstation — not a cluster CRD, not a Kueue Job trigger. The conductor
binary reads the PackBuild spec file directly during compile mode invocation. No cluster Job of
any kind is submitted for pack compilation. The ClusterPack OCI artifact and CR YAML produced
by conductor are the only outputs that reach the cluster (via OCI registry and GitOps). The
capability constant in pkg/runnerlib/constants.go has been moved to its own compile-mode
section with accurate inline semantics. Finding 6-A Option B is fully withdrawn.

**Finding 6-B — Community tier cluster limit: CLOSED.** Resolved authoritatively by the
2026-03-30 redesign. INV-025: 5 target clusters for community tier, management cluster never
counted. License code in conductor must implement this. Carrying forward as CLOSED.

**Finding 6-C — controller-gen not yet wired: REQUIRES GOVERNOR SCHEDULING.** All CRD YAML
and DeepCopy are handwritten. Growing risk as the type surface expands. Recommend inserting
a Schema Engineer session before the next domain (platform or wrapper) implementation
begins. Blocking risk increases with each new type added without generator.

**Finding 6-D — CapabilityRBACProvision semantics under new model:** GOVERNOR DECISION RECEIVED.
Governor preference is executor-mode capability. rbac-provision remains a named Kueue Job
capability. Implementation is non-blocking for this session. REQUIRES Runner Engineer session
for capability implementation.

## Session 6 Pre-Work Review

EPGReconciler state confirmed as of Session 5 (commit 38056c9):
- `reconcileDrift` method exists in `internal/controller/epg_controller.go` at line 269.
  It lists PermissionSnapshots, calls the existing `computeDrift` pure function, and patches
  `Status.Drift`. It does NOT emit events on transitions and does NOT use the new `ComputeDrift`
  semantics (empty expectedVersion edge case). The TODO(session-6) comment marks this method
  as requiring the full implementation.
- `computeDrift` (unexported, line 296) is the existing pure function: `return expected != lastAcked`.
  This does not handle the empty expectedVersion edge case. It will be replaced by `ComputeDrift`
  (exported, in drift.go) with the correct 4-case semantics.
- `SetupWithManager` watches RBACProfile, RBACPolicy, IdentityBinding, PermissionSet via the
  annotation filter, all mapping to fixed key `{namespace: "security-system", name: "epg-trigger"}`.
  No PermissionSnapshotReceipt watch exists yet. No dispatch logic in `Reconcile` — all requests
  go to the full EPG recomputation path.
- `Status.LastAckedVersion` ownership model confirmed: the EPGReconciler never writes this field.
  It is owned exclusively by the management cluster conductor receipt observation loop (which reads
  PermissionSnapshotReceipt from target clusters and propagates the SnapshotVersion to
  PermissionSnapshot.Status.LastAckedVersion). The EPGReconciler reads it in reconcileDrift only.
- Fixed reconcile request key: all epg-trigger events use `{namespace: "security-system", name: "epg-trigger"}`.
  The new drift-check path uses a second fixed key `{namespace: "security-system", name: "drift-check"}`.

## Session 5 EPG Impact Trace

EPG computation impact on PermissionSnapshot generation (documented per CLAUDE.md Step 4b
before any EPG implementation begins):

- **Inputs:** All RBACProfiles with status.Provisioned=true, their governing RBACPolicies,
  all referenced PermissionSets (both declaration-side and ceiling-side), all valid IdentityBindings.
- **Ceiling intersection:** For each provisioned profile, the effective permission set is the
  intersection of the governing policy's MaximumPermissionSetRef PermissionSet (ceiling) and the
  declared PermissionDeclarations. Permissions declared in the profile that are not within the
  ceiling are trimmed from the effective output. This is the policy enforcement mechanism — a
  profile cannot grant more than its governing policy allows. The ceiling is enforced at
  computation time in internal/epg/intersection.go: IntersectWithCeiling.
- **Output:** One PermissionSnapshot CR per target cluster, written to security-system namespace.
  Version is RFC3339 UTC of computation time. GeneratedAt is the same timestamp.
- **Drift detection:** PermissionSnapshotStatus.Drift=true when ExpectedVersion differs from
  the agent's LastAckedVersion in PermissionSnapshotReceipt. Newly generated snapshots always
  have Drift=true because delivery has not yet occurred.
- **Delivery:** Deferred to Session 6. Status.Drift=true is the correct initial state for a
  freshly generated snapshot. Status.LastAckedVersion is owned exclusively by the runner agent
  in agent mode. The EPGReconciler never writes LastAckedVersion.

## Completed Gates (CAPI Governor Amendment Session — 2026-03-30)
- platform-schema.md Section 6 retitled "CRDs Delegated to CAPI for Target Clusters." Dual-path semantics applied to all six lifecycle CRDs. Named runner capability references restored. Amendment record appended.
- platform/platform-design.md Section 2.1 OperationalJobReconciler expanded from seven to thirteen CRDs. CAPIDelegated routing rule added. TalosClusterReset clarified as base extension. Amendment record appended.
- Root CLAUDE.md INV-013 amended to name SeamInfrastructureClusterReconciler and SeamInfrastructureMachineReconciler as the sole talos goclient exceptions. Amendment record appended.
- BACKLOG.md platform section reclassified: six lifecycle CRDs now carry dual-path note. Six new CAPI backlog items added (TalosClusterReconciler CAPI path, SeamInfrastructureClusterReconciler, SeamInfrastructureMachineReconciler, Cilium deployment trigger, TalosNoMaintenanceReconciler, TalosClusterResetReconciler).
- conductor-schema.md capability table updated with Triggering CRD column. Six lifecycle capability constants confirmed retained. Orphaned-constant finding closed. Amendment record appended.
- guardian/AGENTS.md Controller Engineer third-party RBAC intake scope expanded to include CAPI core (installOrder 5) and CABPT (installOrder 6). Amendment record appended.
- platform/AGENTS.md Capability Confirmation Gate replaced with three-category routing: CAPI-managed (no gate), operational runner Job CRDs (full gate), tenant coordination (no gate). Amendment record appended.
- Path B ruling: six lifecycle CRDs retained as direct runner Jobs for capi.enabled=false (management cluster). CAPI-delegated for capi.enabled=true (target clusters). This is the authoritative resolution.
- Files touched: platform-schema.md, platform/platform-design.md, CLAUDE.md, BACKLOG.md, conductor-schema.md, guardian/AGENTS.md, platform/AGENTS.md, PROGRESS.md, GIT_TRACKING.md.

## Completed Gates (Session 7)
- [Session 7] internal/webhook/decision.go — EvaluateAdmission pure function, AnnotationRBACOwner/Value constants, InterceptedKinds, AdmissionRequest/Decision types
- [Session 7] internal/webhook/rbac_handler.go — RBACAdmissionHandler implementing admission.Handler, raw JSON extraction of annotations, delegates to EvaluateAdmission
- [Session 7] internal/webhook/server.go — AdmissionWebhookServer, Register() wires handler at /validate-rbac
- [Session 7] config/webhook/validating-webhook-configuration.yaml — ValidatingWebhookConfiguration for RBAC+ServiceAccount, kube-system excluded, failurePolicy: Fail
- [Session 7] cmd/guardian/main.go — webhook server registered (--webhook-port flag, port 9443 default)
- [Session 7] 13 unit tests passing (test/unit/webhook/decision_test.go) — all EvaluateAdmission branches covered
- [Session 7] 7 integration tests passing (test/integration/webhook/rbac_webhook_test.go) — envtest webhook server live
- [Session 7] Root cause fix: ValidatingWebhookConfiguration YAML had `spec.webhooks` instead of top-level `webhooks` — envtest parsed correctly but webhook array was empty
- [Session 7] Metrics port conflict fixed: all integration test managers now use `Metrics: metricsserver.Options{BindAddress: "0"}` to prevent port 8080 conflicts when tests run in parallel
- [Session 7] All 118 tests passing (92 unit + 26 integration): go vet clean, go build clean
- [Session 7] CS-INV-001 enforced: management cluster admission webhook operational
- [Session 7] CS-INV-004 acknowledged: bootstrap window is TODO(session-8) stub in decision.go

## Completed Gates (Session 6)
- [Session 6] Architectural redesign (2026-03-30) fully absorbed and acknowledged in PROGRESS.md
- [Session 6] Pre-session Governor findings documented (6-A CapabilityPackCompile Option B, 6-B community tier CLOSED, 6-C controller-gen risk, 6-D rbac-provision executor-mode)
- [Session 6] internal/controller/drift.go — DriftResult, ComputeDrift (4-case), ReconcileAllDrift (pure functions)
- [Session 6] reconcileDrift implemented — lists snapshots, calls ReconcileAllDrift, patches status, emits SnapshotDelivered/SnapshotDriftDetected events on transition
- [Session 6] PermissionSnapshotReceipt watch wired → drift-check fixed key
- [Session 6] PermissionSnapshot watch wired → drift-check fixed key (enables Test 1 to work without manual receipt creation)
- [Session 6] Reconcile dispatch: "epg-trigger" → full EPG recomputation; "drift-check" → reconcileDrift only; unknown → logged and ignored
- [Session 6] Old unexported computeDrift removed; superseded by exported ComputeDrift with correct 4-case semantics
- [Session 6] 12 unit tests passing (test/unit/controller/drift_test.go)
- [Session 6] 6 integration tests passing (test/integration/controller/drift_controller_test.go)
- [Session 6] All 79 unit tests passing; all 19 integration tests passing (18 controller + 1 EPG)
- [Session 6] go vet clean, go build clean, go build ./cmd/guardian/ clean
- [Session 6] guardian commit 230e48c

## Completed Gates (Session 5)
- [Session 5] EPG impact trace documented before implementation (CLAUDE.md Step 4b compliance)
- [Session 5] internal/epg/types.go — PrincipalPermissions, EffectiveRule, EPGComputationResult
- [Session 5] internal/epg/intersection.go — IntersectWithCeiling with full ceiling semantics including wildcards and ResourceNames
- [Session 5] internal/epg/compute.go — ComputeEPG, 4-phase algorithm, ceiling enforced at computation time
- [Session 5] internal/epg/snapshot.go — BuildPermissionSnapshot, per-cluster scoping, TypeMeta set for SSA
- [Session 5] EPGReconciler fully implemented — annotation clearing before computation, fixed reconcile key, server-side apply upsert, Status.Drift=true initial state, Status.LastAckedVersion never written
- [Session 5] reconcileDrift method present with TODO(session-6) wiring note; computeDrift pure function extracted for testability
- [Session 5] RBACProfileReconciler: explicit status commit before EPG annotation signal (race condition fix)
- [Session 5] 18 new unit tests passing — compute_test.go (10 tests) + intersection_test.go (8 tests)
- [Session 5] 1 integration test passing in test/integration/epg/ (full EPG cycle)
- [Session 5] All 67 unit tests passing; all 13 integration tests passing
- [Session 5] go vet clean, import constraint verified for internal/epg/ (no client imports)

## Session 5 Exit State

**Commit:** 38056c9 (guardian, branch session/1-governor-init)
**Message:** session/5: EPG computation with ceiling intersection, PermissionSnapshot generation, EPGReconciler, unit and integration tests

**New files created:**
- internal/epg/types.go — PrincipalPermissions, EffectiveRule, EPGComputationResult (no k8s/client imports)
- internal/epg/intersection.go — IntersectWithCeiling with wildcard, ResourceNames, deduplication
- internal/epg/compute.go — ComputeEPG 4-phase algorithm, ceiling enforced at computation time
- internal/epg/snapshot.go — BuildPermissionSnapshot, per-cluster scoping, TypeMeta set for SSA
- test/unit/epg/compute_test.go — 10 unit tests for ComputeEPG
- test/unit/epg/intersection_test.go — 8 unit tests for IntersectWithCeiling
- test/integration/epg/epg_reconciler_test.go — 1 integration test, full EPG cycle with envtest

**Modified files:**
- internal/controller/epg_controller.go — full replacement of stub; fixed reconcile key, annotation clearing, SSA upsert, Drift=true, LastAckedVersion never written
- internal/controller/rbacprofile_controller.go — explicit status commit before EPG annotation signal (race condition fix)
- test/integration/controller/rbacpolicy_controller_test.go — security-system namespace creation for EPGReconciler

**Test counts:** 67 unit tests passing, 13 integration tests passing (12 controller + 1 EPG)

**Import constraint result:** internal/epg/ imports verified clean — no controller-runtime client, no k8s client-go

**TODO items remaining in code:**
- reconcileDrift wiring (Session 6) — TODO(session-6) marker in epg_controller.go
- Admission webhook server — TODO in main.go (Session 6 or later)
- PermissionSnapshot push delivery to target cluster agents (Session 6)
- PermissionSnapshotReceipt watch and LastAckedVersion propagation (Session 6)

## Completed Gates
- [Session 1] Constitutional documents committed to ontai root
- [Session 1] All repository directories initialized with git and initial structure
- [Session 1] Tracking documents created (PROGRESS.md, BACKLOG.md, GIT_TRACKING.md)
- [Session 1] Prompt injection in conductor-schema.md detected and flagged; removed by Platform Governor
- [Session 2] pkg/runnerlib shared library types defined — RunnerConfigSpec, CapabilityManifest, OperationResultSpec, JobSpecBuilder
- [Session 2] All 18 named capability constants defined and verified unique
- [Session 2] Generator implementations: GenerateFromTalosCluster, GenerateFromPackBuild
- [Session 2] JobSpecBuilder concrete implementation with invariant enforcement (value semantics, ReadOnly enforced, defaults applied)
- [Session 2] All 31 unit tests passing, zero lint warnings (go vet clean)
- [Session 3] RBACPolicy CRD types — RBACPolicySpec, RBACPolicyStatus, EnforcementMode, SubjectScope, condition/reason constants
- [Session 3] Manual DeepCopy implementations (zz_generated.deepcopy.go), SetCondition/FindCondition helpers
- [Session 3] ValidateRBACPolicySpec — all-failures collection, 4 checks (scope, mode, cluster format, permset ref)
- [Session 3] RBACPolicyReconciler — fetch, defer status patch, ObservedGeneration, validate, set conditions, emit events
- [Session 3] Controller-runtime manager skeleton (cmd/guardian/main.go) — flags, scheme, leader election, health probes
- [Session 3] CRD YAML (config/crd/security.ontai.dev_rbacpolicies.yaml) — handwritten, envtest-compatible
- [Session 3] 12 unit tests passing (test/unit/controller/rbacpolicy_validation_test.go)
- [Session 3] 5 integration tests passing via envtest (test/integration/controller/rbacpolicy_controller_test.go)
- [Session 3] go vet clean, go build clean

## Completed Gates
- [Session 4] PermissionSet CRD types (PermissionSetSpec, PermissionRule, PermissionSetStatus) and ValidatePermissionSetSpec (4 checks)
- [Session 4] RBACPolicy PermissionSet existence check implemented — deferred TODO(session-4) from Session 3 resolved
- [Session 4] RBACProfile CRD types — Provisioned field, all condition/reason constants (CS-INV-005)
- [Session 4] ValidateRBACProfileSpec (6 checks) and CheckProfilePolicyCompliance (3 rules including audit semantics)
- [Session 4] RBACProfileReconciler — CS-INV-005 enforced; provisioned=true reachable only through Step I
- [Session 4] IdentityBinding CRD types, ValidateIdentityBindingSpec (token TTL hard constraint 900s), stub reconciler
- [Session 4] PermissionSnapshot and PermissionSnapshotReceipt CRD types
- [Session 4] EPGReconciler stub — annotation-triggered, annotation-clearing, no EPG computation yet
- [Session 4] All reconcilers registered in main.go
- [Session 4] 49 unit tests passing (test/unit/controller/)
- [Session 4] 12 integration tests passing including 6 from Session 3 carried forward
- [Session 4] go vet clean, go build clean, go build ./cmd/guardian/ clean

## Session 4 Exit State

**Commit:** 64ac2e8 (guardian, branch session/1-governor-init)

**New files created:**
- api/v1alpha1/permissionset_types.go
- api/v1alpha1/rbacprofile_types.go
- api/v1alpha1/identitybinding_types.go
- api/v1alpha1/permissionsnapshot_types.go
- api/v1alpha1/permissionsnapshotreceipt_types.go
- internal/controller/permissionset_validation.go
- internal/controller/rbacprofile_validation.go
- internal/controller/rbacprofile_compliance.go
- internal/controller/rbacprofile_controller.go
- internal/controller/identitybinding_validation.go
- internal/controller/identitybinding_controller.go
- internal/controller/epg_controller.go
- config/crd/security.ontai.dev_permissionsets.yaml
- config/crd/security.ontai.dev_rbacprofiles.yaml
- config/crd/security.ontai.dev_identitybindings.yaml
- config/crd/security.ontai.dev_permissionsnapshots.yaml
- config/crd/security.ontai.dev_permissionsnapshotreceipts.yaml
- test/unit/controller/permissionset_validation_test.go
- test/unit/controller/rbacprofile_validation_test.go
- test/unit/controller/rbacprofile_compliance_test.go
- test/unit/controller/identitybinding_validation_test.go
- test/integration/controller/rbacprofile_controller_test.go

**Modified files:**
- api/v1alpha1/zz_generated.deepcopy.go (DeepCopy for all new types)
- cmd/guardian/main.go (all 4 reconcilers registered)
- internal/controller/rbacpolicy_controller.go (PermissionSet existence check)
- test/integration/controller/rbacpolicy_controller_test.go (Test 6 + updated Session 3 tests for PermissionSet existence)

**TODO items remaining in code:**
- EPG computation engine (Session 5) — EPGReconciler is a stub
- Admission webhook server (Session 5 or later) — TODO in main.go
- controller-gen wiring for CRD YAML and DeepCopy generation (future session)
- PermissionSnapshot push delivery to target cluster agents (Session 6)

## Session 6 Exit State

**Commit:** 230e48c (guardian, branch session/1-governor-init)
**Message:** session/6: delivery loop — reconcileDrift, PermissionSnapshotReceipt watch, drift dispatch, unit and integration tests

**New files created:**
- internal/controller/drift.go — DriftResult, ComputeDrift (4-case), ReconcileAllDrift
- test/unit/controller/drift_test.go — 12 unit tests
- test/integration/controller/drift_controller_test.go — 6 integration tests

**Modified files:**
- internal/controller/epg_controller.go — dispatch logic added, reconcileDrift replaced, computeDrift removed,
  PermissionSnapshotReceipt and PermissionSnapshot watches added, new epgDriftTriggerName constant

**Test counts:** 79 unit tests passing, 19 integration tests passing (18 controller + 1 EPG)

**TODO items remaining in code:**
- Admission webhook server — TODO in main.go (Session 7)
- CNPG two-phase boot sequence (future session)
- PermissionSet reconciler (ProfileReferenceCount maintenance)
- PermissionService gRPC server

## Open Findings
- [Session 1] Operator repositories reside as subdirectories inside `ontai/`. Proceeding.
- [Session 3] CRD YAML is handwritten. controller-gen not wired. Growing risk. REQUIRES GOVERNOR SCHEDULING.
- [Session 3] DeepCopy manually written. Same note.
- [Session 3] Integration tests require KUBEBUILDER_ASSETS=/tmp/envtest-bins/k8s/1.35.0-linux-amd64. Not persisted across reboots.
- [Session 6, Finding 6-A] CapabilityPackCompile constant semantics: Option B chosen by Governor (validation-only conductor Job). REQUIRES Runner Engineer session to implement. Constant in pkg/runnerlib/constants.go must be annotated before that session.
- [Session 6, Finding 6-B] Community tier cluster limit: CLOSED. Resolved by 2026-03-30 redesign. INV-025: 5 target clusters, management cluster excluded.
- [Session 6, Finding 6-C] controller-gen not wired: REQUIRES GOVERNOR SCHEDULING before next domain begins.
- [Session 6, Finding 6-D] CapabilityRBACProvision semantics: executor-mode Kueue Job (Governor decision). REQUIRES Runner Engineer session.
- [Session 7 → Session 8 CLOSED] Bootstrap RBAC window — CS-INV-004, INV-020. Implemented in Session 8. BootstrapWindow type (atomic bool), Register() closes window permanently. 9 new unit tests. Commit 52e1bb6.
- [Session 6] PermissionSet reconciler absent — ProfileReferenceCount has no owner. Add to backlog.
- [CAPI Governor] Six capability constants (talos-upgrade, kube-upgrade, stack-upgrade, node-scale-up, node-decommission, node-reboot): CLOSED. Confirmed retained. Not orphaned. Active when TalosCluster spec.capi.enabled=false only. conductor-schema.md Triggering CRD column updated.
- [CAPI Governor] INV-013 amendment: CLOSED. Named reconciler exceptions (SeamInfrastructureClusterReconciler, SeamInfrastructureMachineReconciler) added to root CLAUDE.md INV-013 inline text and amendment record.

## Session 1 Exit State
All five repositories initialized. Constitutional documents in ontai root committed
on branch session/1-governor-init. All component repositories initialized with
skeleton structure on branch session/1-governor-init.

Commit hashes:
- conductor:   d176ed9
- guardian: 194934c
- platform: a38188f
- wrapper:    86807d4
- ontai:        d54ac90

## Session 2 Capability Reference

All 18 named capabilities from conductor-schema.md Section 6.
Mode is always executor unless noted. Triggering CRD from operator schemas.

| Constant                    | String Value        | Owner       | Triggering CRD          | Description                                      |
|-----------------------------|---------------------|-------------|-------------------------|--------------------------------------------------|
| CapabilityBootstrap         | bootstrap           | platform| TalosCluster            | Full cluster bootstrap from seed nodes           |
| CapabilityTalosUpgrade      | talos-upgrade       | platform| TalosUpgrade            | Rolling Talos OS version upgrade                 |
| CapabilityKubeUpgrade       | kube-upgrade        | platform| TalosKubeUpgrade        | Kubernetes version upgrade                       |
| CapabilityStackUpgrade      | stack-upgrade       | platform| TalosStackUpgrade       | Coordinated Talos OS + Kubernetes upgrade        |
| CapabilityNodePatch         | node-patch          | platform| TalosNodePatch          | Machine config patch to nodes                    |
| CapabilityNodeScaleUp       | node-scale-up       | platform| TalosNodeScaleUp        | Add nodes to existing cluster                    |
| CapabilityNodeDecommission  | node-decommission   | platform| TalosNodeDecommission   | Cordon, drain, remove node                       |
| CapabilityNodeReboot        | node-reboot         | platform| TalosReboot             | Reboot nodes                                     |
| CapabilityEtcdBackup        | etcd-backup         | platform| TalosBackup             | etcd snapshot + config export to S3              |
| CapabilityEtcdMaintenance   | etcd-maintenance    | platform| TalosEtcdMaintenance    | etcd defrag and optional snapshot                |
| CapabilityEtcdRestore       | etcd-restore        | platform| TalosRecovery           | Disaster recovery from S3 snapshot               |
| CapabilityPKIRotate         | pki-rotate          | platform| TalosPKIRotation        | PKI certificate rotation                         |
| CapabilityCredentialRotate  | credential-rotate   | platform| TalosCredentialRotation | Service account key rotation                     |
| CapabilityHardeningApply    | hardening-apply     | platform| TalosHardeningApply     | Apply TalosHardeningProfile                      |
| CapabilityClusterReset      | cluster-reset       | platform| TalosClusterReset       | Destructive factory reset with human gate        |
| CapabilityPackCompile       | pack-compile        | wrapper   | PackBuild spec file (workstation) | Compile mode capability invoked by conductor binary on workstation or CI — not a Kueue Job |
| CapabilityPackDeploy        | pack-deploy         | wrapper   | PackExecution           | Apply ClusterPack to target cluster              |
| CapabilityRBACProvision     | rbac-provision      | guardian| (agent-initiated)       | Provision RBAC artifacts from snapshot           |

Notes:
- pack-compile is a compile mode capability invoked by the conductor binary on the workstation
  or in CI. It is not a Kueue Job. PackBuild is a local spec file, not a cluster CRD. The
  Session 2 description ("executor Job") was incorrect and is superseded by this correction
  (2026-04-01, Finding 6-A final resolution).
- cluster-reset is multi-step and uses the PVC protocol (conductor-design.md §5.6).
- bootstrap is multi-step and uses the PVC protocol.
- stack-upgrade is multi-step and uses the PVC protocol.

## Session 2 Exit State

**Commit:** 56e1582 (conductor, branch session/1-governor-init)

**Files created in pkg/runnerlib/:**
- doc.go — package-level godoc
- constants.go — 18 named capability constants
- runnerconfig.go — RunnerConfigSpec, PhaseConfig, OperationalHistoryEntry, SecretRef, RunnerConfigStatus, LicenseStatus
- capability.go — CapabilityManifest, CapabilityEntry, CapabilityMode, ParameterDef
- operationresult.go — OperationResultSpec, ResultStatus, ArtifactRef, FailureReason, FailureCategory, StepResult
- jobspec.go — JobSpecBuilder interface, jobSpecBuilder implementation, NewJobSpecBuilder, JobSpec, SecretVolume
- generators.go — TalosClusterSpec, PackBuildSpec, HelmSource, KustomizeSource, RawManifestSource, GenerateFromTalosCluster, GenerateFromPackBuild

**Test files created in test/unit/runnerlib/:**
- runnerconfig_test.go — 4 tests
- capability_test.go — 4 tests
- operationresult_test.go — 5 tests
- jobspec_test.go — 6 tests (including subtests)
- generators_test.go — 6 tests
- constants_test.go — 5 tests
- Total: 31 tests, 31 passing

**go mod tidy:** Clean. go.sum generated.

**Lint:** go vet clean. staticcheck and golangci-lint not installed.

**TODOs in code (non-blocking, carry to future sessions):**
- generators.go: ClusterEndpoint used as cluster identity pending formal name field
  on TalosCluster CRD. Flagged with TODO comment.
- generators.go: RunnerImage left empty by generators — callers set this.
  Documented in godoc.

## Session 3 Exit State

**Commit:** c205ea5 (guardian, branch session/1-governor-init)

**Files created in api/v1alpha1/:**
- groupversion_info.go — GroupVersion, SchemeBuilder, AddToScheme
- rbacpolicy_types.go — EnforcementMode, SubjectScope, condition/reason constants, RBACPolicySpec, RBACPolicyStatus, RBACPolicy, RBACPolicyList
- zz_generated.deepcopy.go — manual DeepCopy implementations for all types
- conditions.go — SetCondition, FindCondition helpers

**Files created in internal/controller/:**
- rbacpolicy_validation.go — ValidationCheckName constants, PolicyValidationResult, ValidateRBACPolicySpec (4 checks, all-failures collection)
- rbacpolicy_controller.go — RBACPolicyReconciler (fetch, defer status patch, ObservedGeneration, validate, set conditions, emit events), SetupWithManager with GenerationChangedPredicate

**Files created in cmd/guardian/:**
- main.go — flag parsing, scheme setup, RBACPolicyReconciler registration, health/readiness probes, leader election (lease: guardian-leader, namespace: security-system)

**Files created in config/crd/:**
- security.ontai.dev_rbacpolicies.yaml — handwritten CRD YAML, envtest-compatible

**Test files:**
- test/unit/controller/rbacpolicy_validation_test.go — 12 tests, all passing
- test/integration/controller/rbacpolicy_controller_test.go — 5 tests via envtest, all passing

**go mod tidy:** Clean. go.sum generated.

**Lint:** go vet clean.

**TODOs in code (non-blocking, carry to future sessions):**
- rbacpolicy_controller.go: TODO(session-4) comment for PermissionSet existence check at
  policy.Spec.MaximumPermissionSetRef. To be added after PermissionSet types are defined.
- main.go: TODO comments for future reconcilers (RBACProfile, EPG, IdentityBinding) and
  webhook server registration.

**Integration test note:**
Tests require KUBEBUILDER_ASSETS=/tmp/envtest-bins/k8s/1.35.0-linux-amd64.
Run: setup-envtest use --bin-dir /tmp/envtest-bins to restore if absent.

## Session 19 Exit State — Controller Engineer (platform)

**Role:** Controller Engineer — platform repository

**Commit:** 8c02a4f (platform, branch session/1-governor-init)

### Workstream 1 — TalosCluster CRD types and reconciler scaffold: COMPLETE

**Files created in api/v1alpha1/:**
- groupversion_info.go — GroupVersion `platform.ontai.dev/v1alpha1`, SchemeBuilder, AddToScheme
- taloscluster_types.go — TalosClusterMode, TalosClusterOrigin, condition/reason constants, CAPICiliumPackRef, CAPIWorkerPool, CAPIControlPlaneConfig, CAPIConfig, TalosClusterSpec (with `spec.lineage *lineage.SealedCausalChain` from seam-core), LocalObjectRef, TalosClusterStatus, TalosCluster, TalosClusterList; kubebuilder markers including shortName=tc
- conditions.go — SetCondition, FindCondition helpers (exact guardian pattern)
- lineage_conditions.go — ConditionTypeLineageSynced, ReasonLineageControllerAbsent
- zz_generated.deepcopy.go — controller-gen output, all types covered

**Files created in config/crd/:**
- platform.ontai.dev_talosclusters.yaml — controller-gen output, clean

**Files created in internal/controller/:**
- taloscluster_controller.go — TalosClusterReconciler: fetch TalosCluster, deferred status patch, ObservedGeneration advance, one-time LineageSynced=False/LineageControllerAbsent init (seam-core-schema.md §7 Declaration 5), route by spec.capi.enabled; reconcileDirectBootstrap (bootstrap Job submit, OperationResult poll, Ready transition); reconcileCAPIPath (10-step CAPI flow, Cilium gate); transitionToReady; SetupWithManager
- taloscluster_helpers.go — bootstrapPollInterval=15s, capiPollInterval=20s, bootstrapCapability="cluster-bootstrap"; getBootstrapJob, submitBootstrapJob (BackoffLimit=0, INV-018, TTL=600, ownerRef), readOperationResult; ensureTenantNamespace (CP-INV-004), ensureSeamInfrastructureCluster, ensureCAPICluster, ensureTalosConfigTemplate (CNI=none + Cilium BPF params, CP-INV-009), ensureTalosControlPlane, ensureWorkerPool, getCAPIClusterPhase, isCiliumPackInstanceReady, boolPtr; all CAPI objects via unstructured.Unstructured (avoids sigs.k8s.io/cluster-api dependency); all CAPI objects carry TalosCluster ownerRef (CP-INV-008)

**Files created in cmd/ont-platform/:**
- main.go — flag parsing, scheme setup (clientgoscheme + platformv1alpha1), ctrl.NewManager with CP-INV-007 leader election (platform-leader / platform-system), TalosClusterReconciler registration, health/readiness probes

**go.mod:** seam-core replace directive added; k8s.io and controller-runtime dependencies resolved
**go mod tidy:** Clean
**make generate (controller-gen):** Clean — deepcopy and CRD YAML generated without errors
**go build ./...:** Clean — no compiler errors

### Open Items / Next Session

**WS2 — Seam Infrastructure Provider (not yet started):**
- SeamInfrastructureCluster and SeamInfrastructureMachine CRD types in api/infrastructure/v1alpha1/
- SeamInfrastructureClusterReconciler — CAPI InfrastructureCluster contract, controlPlaneEndpoint write-back
- SeamInfrastructureMachineReconciler — 6-step machineconfig delivery via talos goclient (platform-design.md §3.1); only file in this codebase permitted to use talos goclient (CP-INV-001)
- Wire both reconcilers into main.go
- Unit tests

**Notes:**
- CAPI objects use unstructured.Unstructured throughout — deliberate to avoid heavy sigs.k8s.io/cluster-api import
- Bootstrap Job image uses placeholder `registry.ontai.dev/ontai-dev/conductor:latest` with TODO comment; real image comes from RunnerConfig once SC-INV-002 migration is complete
- gopls BrokenImport diagnostics are workspace config noise (module not in go.work); `go build ./...` is the real compiler gate

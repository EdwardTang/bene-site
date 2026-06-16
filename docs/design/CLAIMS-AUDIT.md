# BENE 2.0 — Claims Audit (2026-06-13)

Every capability claim in `BENE2-DESIGN.md`, marked **implemented** (file + test
reference) or **planned** (tracked, not shipped). Zero false "done" claims —
this document is the trust pillar applied to ourselves. Suite at audit time:
**614 tests passing (+3 skipped)** (`uv run python -m pytest tests/ -q`);
re-measured after the Round-3 gap-closure work: **699 passing (+3 skipped)**.
Current (2026-06-13, fully-synced env): **741 passing (+1 skipped, 0 failed)** —
the count includes the Temporal runtime suite when `temporalio` is installed
and the GOO-16 claim-audit milestone tests for runner ContextOS packing, live
loop guards, scheduled consolidation planning, and the meta-harness evolution
bridge. Pass/skip counts drift per env; the invariant is **0 failed**.

## Pillar claims

| Claim (BENE2-DESIGN §2) | Status | Verification | Evidence |
|---|---|---|---|
| Engram substrate: typed kinds, mandatory provenance, content-addressed payloads | **implemented** | **VERIFIED** | `bene/kernel/engrams.py` · `tests/kernel/test_engrams.py` (22) |
| Compression ladder w/ append-only promotion + lineage queries | **implemented** | **VERIFIED** | `EngramStore.promote/lineage` · `test_lineage_three_generations`, `test_promote_never_mutates_source` |
| Event bus w/ handler isolation + legacy journal mirror | **implemented** | **VERIFIED** | `bene/kernel/bus.py` · `tests/kernel/test_bus.py` (8) |
| Capability registry w/ autonomy metadata + dispatch enforcement | **implemented** | **VERIFIED** | `bene/kernel/capabilities.py` · `tests/kernel/test_capabilities.py` (11) |
| Falsifiable probes: sha256 locks, tamper refusal (both directions), admissibility-at-registration, A/R/V verdicts as engrams | **implemented** | **VERIFIED** | `bene/kernel/eval/` · `tests/kernel/test_eval.py` (14) |
| Experiments journal + CLI | **implemented** | **VERIFIED** | `experiment_runs` table · `bene experiments ls/show` · `test_experiment_run_logged_per_probe_run` |
| Trust ledger: 4 computed signals + composite, L3+ needs ACCEPT, weighted votes | **implemented** | **VERIFIED** | `bene/kernel/trust.py` · `tests/kernel/test_trust.py` (12) |
| Consolidation passes (episodic→semantic→procedural) | **implemented** (mechanism) | **VERIFIED** | `GranuleStore.consolidate`, `TraceDistiller` · `test_memory_os.py`, `test_evolve.py` |
| Scheduled/nightly consolidation automation (SkillClaw-style) | **implemented** | **VERIFIED** | `bene consolidate plan/run/ls/show` — cron-spawnable, exit 0 (ran/interval-skip) / 1 (error/unknown-policy) / 2 (insufficient-turns) — over `ScheduledConsolidator`, with built-in + `kernel.consolidation` policies (`bene/cli/main.py` · `bene/config.py` · `tests/test_cli_consolidate.py` + `tests/test_consolidation_config.py`). No in-process daemon by scope — operators wire cron/systemd/launchd |
| Skill plasticity: decay / demotion / retirement of failing skills | **implemented** | **VERIFIED** | outcome-weighted ranking (Round-3) + `PlasticityScanner` probe-gated demotion/retirement (ACCEPT=degraded→demote, REJECT=hold, VOID=hold): append-only `skill_lifecycle` audit + `eval`/`intervention` engrams linked `gated_by`; `search(include_demoted=False)` drops demoted; `bene skills plasticity scan/lifecycle/restore` (`bene/kernel/memory/plasticity.py` · `bene/skills.py` · `tests/kernel/test_plasticity.py` (9) + `tests/test_skills_plasticity_search.py`). Closes GAP-AUDIT BENE-4 |
| Outcome-weighted retrieval ranking (BM25 × Wilson lower bound × recency, opt-in `rank="weighted"`) | **implemented** | **VERIFIED** | `bene/skills.py` · `tests/test_skills_weighted.py` (Round-3; closes bench rows A1b/A2) |
| Continuous-quality outcome signal (`record_outcome(…, quality=…)` + per-use telemetry) | **implemented** | **VERIFIED** | `bene/skills.py` · `tests/test_skills_weighted.py` (Round-3; closes bench row A5) |
| Critical-step localizer: earliest decisive error over failed trajectories, heuristic-first, optional cached LLM fallback | **implemented** | **VERIFIED** | `bene/kernel/evolve/localize.py` · `tests/kernel/test_localize.py` (Round-3; closes bench row A4) |
| Evolution: structured genomes, reflective mutation, Pareto frontier, surrogate prefilter | **implemented** | **VERIFIED** | `bene/kernel/evolve/gepa.py` · `tests/kernel/test_evolve.py` (18) |
| Trace→skill distillation: patches, prevalence merge, 3-level hierarchy, full provenance | **implemented** | **VERIFIED** | `bene/kernel/evolve/distill.py` · `test_distill_provenance_to_every_source_trace` |
| Strategy genes (encode/decode/merge, control-signal-dense) | **implemented** | **VERIFIED** | `bene/kernel/evolve/genes.py` · 4 gene tests |
| Kill-gated promotion (`PromotionBlocked`) w/ verifier isolation | **implemented** | **VERIFIED** | `evolve.promote` · `test_promotion_blocked_without_accept` + 2 |
| In-episode/continual harness mutation (Continual Harness) | **implemented** | **VERIFIED** | `ContinualMutator.maybe_mutate` swaps one genome component mid-episode ONLY behind a registered probe ACCEPT → `promote()` front door → `continual_swaps` audit + active-genome pointer; REJECT/VOID hold; autonomy L3 cap `evolve.in_episode_swap`; budgets (min_turns/max_swaps); default swappable = context_strategy/retrieval_policy. `bene evolve continual status` read surface (`bene/kernel/evolve/continual.py` · `tests/kernel/test_continual.py` (9)). Runner auto-trigger wiring (loop-guard/pollution → maybe_mutate) deferred per the §7 adversarial split-scope |
| metaharness → evolve backend | **implemented** | **VERIFIED** | candidates bridge to tier-4 genome engrams AND auto-promote through the kill gate: `gated_promote` / `auto_promote_evolved` / `build_improvement_probe` (`bene/kernel/evolve/autopromote.py`) run an admissible improvement probe and call `promote()` ONLY on ACCEPT (REJECT/VOID → held). Opt-in `SearchConfig.auto_promote` wires it into `MetaHarnessSearch._store_result` (`tests/test_mh_autopromote.py` (8)). No back-door — `promote()` still demands the ACCEPT verdict |
| Granules: 4 levels = ladder tiers, associations | **implemented** | **VERIFIED** | `bene/kernel/memory/granules.py` · 5 tests |
| Adaptive fast/slow retrieval w/ auditable path metadata | **implemented** | **VERIFIED** | `bene/kernel/memory/retrieval.py` · `test_both_paths_recorded_distinctly` |
| MemGAS entropy-routed multi-granularity retrieval | **implemented** | **VERIFIED** | `MemGASRouter` (opt-in subclass of `AdaptiveRetriever`): per-tier normalized entropy of softmax(-bm25) → softmin tier routing → weighted merge → familiarity fast/slow. `bene retrieve` CLI + `kernel.memgas` config opt-in (`bene/kernel/memory/retrieval.py` · `bene/cli/main.py` · `bene/config.py` · `tests/kernel/test_memgas.py` (8) + `tests/test_cli_retrieve.py`). Default stays `AdaptiveRetriever`; default-flip gated on probe ACCEPT |
| ContextOS: 3 strategies, signal routing, budget-capped manifests | **implemented** | **VERIFIED** | `bene/kernel/memory/contextos.py` · `test_budget_never_exceeded_randomized` |
| Runner uses ContextOS packing (opt-in) | **implemented** | **VERIFIED** | `ccr/runner.py` packs model messages through `ContextOS` only when enabled and records manifests in agent state · `test_context_os_packing_is_opt_in_for_runner` |
| Pollution detection (3 documented signals) + consolidate-then-restore | **implemented** | **VERIFIED** | `bene/kernel/memory/pollution.py` · `test_recovery_restores_real_checkpoint` |
| VEA-style evidence re-highlighting before re-retrieval | **implemented** | **VERIFIED** | `EvidenceRehighlighter` foregrounds in-context items matching the consolidated intent + dims the rest (deterministic term-overlap score, auditable manifest); `PollutionDetector.rehighlight` + `recover(reask=…)` make it the cheap first rung of the recovery ladder — gated on `evidence_present`, restore is SKIPPED when re-asking with the re-highlighted context succeeds, and it escalates to consolidate→restore otherwise. `bene memory rehighlight` read surface (`bene/kernel/memory/rehighlight.py` · `bene/kernel/memory/pollution.py` · `bene/cli/main.py` · `tests/kernel/test_memory_os.py` (+13)). Live-runner auto-trigger deferred (consistent with the §pollution recovery split-scope). |
| Autonomy ladder L0–L4 enforced, per-domain, L4 human-only, denials → trust engrams | **implemented** | **VERIFIED** | `bene/kernel/harness/autonomy.py` · 7 tests |
| Agent senses manifest generated from live db + CLI | **implemented** | **VERIFIED** | `bene/kernel/harness/senses.py` · `bene senses` · 3 tests |
| Debt sweeper (4 signatures, report engrams) + CLI | **implemented** | **VERIFIED** | `bene/kernel/harness/sweeper.py` · `bene sweep` · 4 tests |
| Loop guards (repetition + oscillation, removable middleware) | **implemented** | **VERIFIED** | `bene/kernel/harness/guards.py` · 5 tests |
| Runner wires loop-guard middleware into the live agent loop | **implemented** | **VERIFIED** | `ccr/runner.py` observes tool calls before execution and injects loop-guard tool observations/intervention engrams · `test_loop_guard_blocks_repeated_tool_call` |
| Adapters: memory/skills/shared_log mirror into engrams (explicit attach); detached = byte-identical legacy | **implemented** | **VERIFIED** | `bene/kernel/adapters.py` · `tests/kernel/test_adapters.py` (Round-3 adds batched mirrors: ~0.31 ms/write amortized incl. flush, documented durability contract) |
| Trust-weighted shared-log tally | **implemented** | **VERIFIED** | `weighted_tally` via adapter · `test_weighted_tally_added_when_attached` |
| Spec-as-artifact workflow (proposal→acceptance gating) | **implemented** | **VERIFIED** | `SpecWorkflow` (`bene/kernel/spec.py`): `propose` (kind=proposal) → `accept` creates a `spec` engram `derived_from` the proposal + `gated_by` an ACCEPT verdict ONLY behind a probe ACCEPT eval engram OR a named-human decision (`SpecGateBlocked` otherwise); `reject` append-only; status derived from the link graph. `bene spec propose/accept/reject/ls` CLI + senses (`tests/kernel/test_spec.py`) |
| Deterministic replay surfaces (`bene replay` export/verify/cite; ed25519-signed self-contained envelopes) | **implemented** | **VERIFIED** | `bene/kernel/replay/` (manifest/exporter/verifier/keys) · `bene replay` CLI group (`bene/cli/main.py`) · `tests/kernel/test_replay.py` (19) + `tests/test_cli_replay.py` (7). Covers `kind=consolidation` (re-plan the deterministic batcher) AND `kind=probe` (re-hash the locked gate spec → `lock_sha256`, re-derive the verdict from the recorded gate values; tamper → `probe-lock-mismatch`/`verdict-status-mismatch`/`gate-result-inconsistent`) — so a held-out promotion (C2) is independently re-derivable + signed-citable; evolution kind is the remaining follow-up |
| `bene.yaml` `kernel:` config section (enabled, autonomy defaults, consolidation schedule) | **implemented** | **VERIFIED** | `kernel.context_os`, `kernel.loop_guard`, `kernel.observability`, `kernel.consolidation`, and `kernel.autonomy` now wire through config/CLI; consolidation schedule shipped (row 26); **autonomy defaults shipped** — `autonomy_config_from_config`/`autonomy_policy_from_config[_file]` parse `kernel.autonomy.{default_level,grants}` (default_level is a 0..3 floor; L4 stays human-grant-only) + `bene autonomy show/grant` CLI (`bene/config.py` · `bene/kernel/harness/autonomy.py` · `bene/cli/main.py` · `tests/test_config.py` (+7) · `tests/kernel/test_harness_layer.py` (+6)) |
| `bene demo` 5-pillar story, keyless, fresh dir, <60s | **implemented** (0.6s measured) | **VERIFIED** | `_kernel_story` in `bene/cli/main.py` · `test_demo_no_ui_runs_clean` |
| UI engram browser + trust panel | **implemented** | **VERIFIED** | `/api/engrams`, `/api/trust/{id}` + Engrams/Trust tabs · curl-verified |
| First-run CLI guidance | **implemented** | **VERIFIED** | `bene ls` missing-db path · `test_ls_first_run_guidance_json` |
| v0.2.0 everywhere | **implemented** | **VERIFIED** | pyproject / `__init__` / CLI / uv.lock greps |

## Subsumption-table verdicts (BENE2-DESIGN §4, 55 rows)

- **20 kept / 11 kept+** rows: hold by construction — legacy modules untouched, full legacy suite green at every phase commit (the per-phase gate). (#45 UI panels is kept+: legacy UI kept, engram/trust panels added ✓.)
- **17 surpassed** rows: #4 (pollution-recovery wrapper ✓), #10 (eval+admissibility ✓), #15/42 (ContextOS ✓), #16 (UI panels ✓), #17 (demo story ✓), #20/37 (granules+adaptive retrieval ✓), #21/38 (procedural engrams w/ provenance ✓; plasticity decay planned), #22/39 (weighted tally ✓), #25/48 (gated promotion + structured genomes ✓; full mh integration partial), #29 (ladder ✓), #32 (senses-from-db ✓), #55 (engram FTS + lineage ✓).
- **7 re-derived** rows: #6/7 dream/neuroplasticity → consolidation mechanism ✓, scheduled consolidation helper **partial**, external scheduler + demotion/retirement policy **planned**; #8/9 failure intelligence/localizer → evidence-chain analysts ✓ (distill), dedicated failure-lookup CLI ✓ (`bene failure localize` over `localize_steps`/`steps_from_engrams`, blames the earliest decisive step in a run's trace engrams; `tests/test_cli_failure.py`); #11 experiments ✓; #12 ISA → probe gate specs ✓; #28 doctor/alerts → senses+sweeper+guards ✓.

## Beyond-both capabilities (BENE2-DESIGN §5)

| # | Capability | Status | Verification |
|---|---|---|---|
| 1 | Engram ladder w/ mandatory provenance | **implemented** | **VERIFIED** |
| 2 | Pollution detection + consolidate-then-recover | **implemented** | **VERIFIED** |
| 3 | Enforced autonomy ladder, per-domain | **implemented** | **VERIFIED** |
| 4 | Computed trust ledger + weighted consensus | **implemented** | **VERIFIED** |
| 5 | Kill-gated promotion | **implemented** | **VERIFIED** |
| 6 | Strategy genes + structured genomes | **implemented** | **VERIFIED** |
| 7 | Adaptive fast/slow retrieval, auditable | **implemented** | **VERIFIED** |
| 8 | Senses generated from live db | **implemented** | **VERIFIED** |

## Known polish notes (tracked, non-blocking)

- GenomeFrontier keeps score-tied duplicate members (legal non-dominated set; dedupe is cosmetic).
- `bene/integrations/` remains a docstring-only namespace (GAP-AUDIT BENE-13) — left for the first real domain package; noted here instead of deleted to avoid breaking import paths. (`bene/benchmarks/` was in the same state as of the original audit, but the gap closed when the `bug_triage` sub-package landed — 12 modules, ~3041 LOC — restored under `bene/benchmarks/bug_triage/` after the migration gitignore B3 fix.)

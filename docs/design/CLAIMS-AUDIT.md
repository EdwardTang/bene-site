# BENE 2.0 — Claims Audit (2026-06-11)

Every capability claim in `BENE2-DESIGN.md`, marked **implemented** (file + test
reference) or **planned** (tracked, not shipped). Zero false "done" claims —
this document is the trust pillar applied to ourselves. Suite at audit time:
**614 tests passing (+3 skipped)** (`uv run python -m pytest tests/ -q`);
re-measured after the Round-3 gap-closure work: **699 passing (+3 skipped)**.
Current (2026-06-12, fully-synced env): **718 passing (+1 skipped, 0 failed)** —
the +19 over 699 is the 22-test Temporal runtime suite
(`tests/test_runtime_handle.py` + `tests/test_runtime_invariants.py`), which
collects only when `temporalio` is installed; pass/skip counts drift per env,
the invariant is **0 failed**.

## Pillar claims

| Claim (BENE2-DESIGN §2) | Status | Evidence |
|---|---|---|
| Engram substrate: typed kinds, mandatory provenance, content-addressed payloads | **implemented** | `bene/kernel/engrams.py` · `tests/kernel/test_engrams.py` (22) |
| Compression ladder w/ append-only promotion + lineage queries | **implemented** | `EngramStore.promote/lineage` · `test_lineage_three_generations`, `test_promote_never_mutates_source` |
| Event bus w/ handler isolation + legacy journal mirror | **implemented** | `bene/kernel/bus.py` · `tests/kernel/test_bus.py` (8) |
| Capability registry w/ autonomy metadata + dispatch enforcement | **implemented** | `bene/kernel/capabilities.py` · `tests/kernel/test_capabilities.py` (11) |
| Falsifiable probes: sha256 locks, tamper refusal (both directions), admissibility-at-registration, A/R/V verdicts as engrams | **implemented** | `bene/kernel/eval/` · `tests/kernel/test_eval.py` (14) |
| Experiments journal + CLI | **implemented** | `experiment_runs` table · `bene experiments ls/show` · `test_experiment_run_logged_per_probe_run` |
| Trust ledger: 4 computed signals + composite, L3+ needs ACCEPT, weighted votes | **implemented** | `bene/kernel/trust.py` · `tests/kernel/test_trust.py` (12) |
| Consolidation passes (episodic→semantic→procedural) | **implemented** (mechanism) | `GranuleStore.consolidate`, `TraceDistiller` · `test_memory_os.py`, `test_evolve.py` |
| Scheduled/nightly consolidation automation (SkillClaw-style) | **planned** | mechanism exists; scheduler/cron wiring not shipped |
| Skill plasticity: decay / demotion / retirement of failing skills | **partial** | search-time outcome weighting + recency decay shipped (Round-3, below); demotion/retirement policy still planned (GAP-AUDIT BENE-4 partially open) |
| Outcome-weighted retrieval ranking (BM25 × Wilson lower bound × recency, opt-in `rank="weighted"`) | **implemented** | `bene/skills.py` · `tests/test_skills_weighted.py` (Round-3; closes bench rows A1b/A2) |
| Continuous-quality outcome signal (`record_outcome(…, quality=…)` + per-use telemetry) | **implemented** | `bene/skills.py` · `tests/test_skills_weighted.py` (Round-3; closes bench row A5) |
| Critical-step localizer: earliest decisive error over failed trajectories, heuristic-first, optional cached LLM fallback | **implemented** | `bene/kernel/evolve/localize.py` · `tests/kernel/test_localize.py` (Round-3; closes bench row A4) |
| Evolution: structured genomes, reflective mutation, Pareto frontier, surrogate prefilter | **implemented** | `bene/kernel/evolve/gepa.py` · `tests/kernel/test_evolve.py` (18) |
| Trace→skill distillation: patches, prevalence merge, 3-level hierarchy, full provenance | **implemented** | `bene/kernel/evolve/distill.py` · `test_distill_provenance_to_every_source_trace` |
| Strategy genes (encode/decode/merge, control-signal-dense) | **implemented** | `bene/kernel/evolve/genes.py` · 4 gene tests |
| Kill-gated promotion (`PromotionBlocked`) w/ verifier isolation | **implemented** | `evolve.promote` · `test_promotion_blocked_without_accept` + 2 |
| In-episode/continual harness mutation (Continual Harness) | **planned** | between-generation only today |
| metaharness → evolve backend | **partial** | `adapters.genome_from_candidate` bridge implemented + tested; mh_search does not yet drive the kill-gated loop end-to-end |
| Granules: 4 levels = ladder tiers, associations | **implemented** | `bene/kernel/memory/granules.py` · 5 tests |
| Adaptive fast/slow retrieval w/ auditable path metadata | **implemented** | `bene/kernel/memory/retrieval.py` · `test_both_paths_recorded_distinctly` |
| MemGAS entropy-routed multi-granularity retrieval | **planned** | deterministic familiarity heuristic shipped instead (documented, pluggable) |
| ContextOS: 3 strategies, signal routing, budget-capped manifests | **implemented** | `bene/kernel/memory/contextos.py` · `test_budget_never_exceeded_randomized` |
| Runner uses ContextOS packing (opt-in) | **planned** | ContextOS standalone; `ccr/runner.py` not yet wired |
| Pollution detection (3 documented signals) + consolidate-then-restore | **implemented** | `bene/kernel/memory/pollution.py` · `test_recovery_restores_real_checkpoint` |
| VEA-style evidence re-highlighting before re-retrieval | **planned** | cited in design; not shipped |
| Autonomy ladder L0–L4 enforced, per-domain, L4 human-only, denials → trust engrams | **implemented** | `bene/kernel/harness/autonomy.py` · 7 tests |
| Agent senses manifest generated from live db + CLI | **implemented** | `bene/kernel/harness/senses.py` · `bene senses` · 3 tests |
| Debt sweeper (4 signatures, report engrams) + CLI | **implemented** | `bene/kernel/harness/sweeper.py` · `bene sweep` · 4 tests |
| Loop guards (repetition + oscillation, removable middleware) | **implemented** | `bene/kernel/harness/guards.py` · 5 tests |
| Runner wires loop-guard middleware into the live agent loop | **planned** | guard is standalone; `ccr/runner.py` hook not shipped |
| Adapters: memory/skills/shared_log mirror into engrams (explicit attach); detached = byte-identical legacy | **implemented** | `bene/kernel/adapters.py` · `tests/kernel/test_adapters.py` (Round-3 adds batched mirrors: ~0.31 ms/write amortized incl. flush, documented durability contract) |
| Trust-weighted shared-log tally | **implemented** | `weighted_tally` via adapter · `test_weighted_tally_added_when_attached` |
| Spec-as-artifact workflow (proposal→acceptance gating) | **partial** | engram kind `spec`/`proposal` + mirrors shipped; full SDD gating workflow planned |
| Deterministic replay surfaces | **planned** | journal + checkpoints are the substrate; replay tooling not shipped |
| `bene.yaml` `kernel:` config section (enabled, autonomy defaults, consolidation schedule) | **planned** | no code reads a `kernel:` key today; kernel tables are created lazily on first kernel command or `attach_kernel` (sane defaults, no config required) |
| `bene demo` 5-pillar story, keyless, fresh dir, <60s | **implemented** (0.6s measured) | `_kernel_story` in `bene/cli/main.py` · `test_demo_no_ui_runs_clean` |
| UI engram browser + trust panel | **implemented** | `/api/engrams`, `/api/trust/{id}` + Engrams/Trust tabs · curl-verified |
| First-run CLI guidance | **implemented** | `bene ls` missing-db path · `test_ls_first_run_guidance_json` |
| v0.2.0 everywhere | **implemented** | pyproject / `__init__` / CLI / uv.lock greps |

## Subsumption-table verdicts (BENE2-DESIGN §4, 55 rows)

- **20 kept / 11 kept+** rows: hold by construction — legacy modules untouched, full legacy suite green at every phase commit (the per-phase gate). (#45 UI panels is kept+: legacy UI kept, engram/trust panels added ✓.)
- **17 surpassed** rows: #4 (pollution-recovery wrapper ✓), #10 (eval+admissibility ✓), #15/42 (ContextOS ✓), #16 (UI panels ✓), #17 (demo story ✓), #20/37 (granules+adaptive retrieval ✓), #21/38 (procedural engrams w/ provenance ✓; plasticity decay planned), #22/39 (weighted tally ✓), #25/48 (gated promotion + structured genomes ✓; full mh integration partial), #29 (ladder ✓), #32 (senses-from-db ✓), #55 (engram FTS + lineage ✓).
- **7 re-derived** rows: #6/7 dream/neuroplasticity → consolidation mechanism ✓, scheduler + decay **planned**; #8/9 failure intelligence/localizer → evidence-chain analysts ✓ (distill), dedicated failure-lookup CLI **planned**; #11 experiments ✓; #12 ISA → probe gate specs ✓; #28 doctor/alerts → senses+sweeper+guards ✓.

## Beyond-both capabilities (BENE2-DESIGN §5)

| # | Capability | Status |
|---|---|---|
| 1 | Engram ladder w/ mandatory provenance | **implemented** |
| 2 | Pollution detection + consolidate-then-recover | **implemented** |
| 3 | Enforced autonomy ladder, per-domain | **implemented** |
| 4 | Computed trust ledger + weighted consensus | **implemented** |
| 5 | Kill-gated promotion | **implemented** |
| 6 | Strategy genes + structured genomes | **implemented** |
| 7 | Adaptive fast/slow retrieval, auditable | **implemented** |
| 8 | Senses generated from live db | **implemented** |

## Known polish notes (tracked, non-blocking)

- GenomeFrontier keeps score-tied duplicate members (legal non-dominated set; dedupe is cosmetic).
- `bene/benchmarks/` and `bene/integrations/` remain docstring-only namespaces (GAP-AUDIT BENE-13) — left for the first real domain package; noted here instead of deleted to avoid breaking import paths.

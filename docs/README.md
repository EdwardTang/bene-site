# BENE Documentation

**Breeding-program Evolutionary Nexus for Engrams** — runtime infrastructure for multi-agent AI.

Every agent gets an isolated filesystem, automatic checkpointing, a full audit trail, and a live dashboard — all in a single SQLite file.

---

## Get started

```bash
git clone https://github.com/good-night-oppie/bene.git && cd bene
uv sync
bene setup       # configure models, init database, install MCP server
bene demo        # see it in action — no API keys needed
```

---

## Philosophy

| | |
|---|---|
| [Design Philosophy](philosophy.md) | Why BENE integrates research rather than inventing solutions, integration criteria, what's next |

---

## Guides

| Guide | What it covers |
|---|---|
| [Dashboard](dashboard.md) | Gantt timeline, agent inspector, live events, multi-project |
| [Checkpoints](checkpoints.md) | Snapshot, restore, diff, auto-checkpointing, storage |
| [Use Cases](use-cases.md) | Code review swarm, parallel refactor, self-healing, post-mortem, incident response, ML research |
| [MCP Integration](mcp-integration.md) | Claude Code / Cursor setup, all 25 MCP tools |
| [Meta-Harness](meta-harness.md) | Automated prompt/strategy optimization search |
| [CLI Reference](cli-reference.md) | Every command, every flag |
| [Cross-Agent Memory](memory.md) | FTS5 searchable memory across agents and sessions |
| [Skill Library](skills.md) | FTS5 cross-agent procedural skill templates with usage tracking |
| [Shared Log](shared-log.md) | LogAct intent/vote/decide coordination protocol |

---

## Reference

| Reference | What it covers |
|---|---|
| [Schema](schema.md) | All 10 SQLite tables, columns, indexes |
| [Architecture](architecture.md) | Internal subsystems, data flow, design decisions |
| [Deployment](deployment.md) | vLLM setup, production config, Docker |

---

## Tutorials

**Component-deep tutorials**:

| Tutorial | What it covers |
|---|---|
| [t11 — Local Agents with vLLM](tutorials/t11-local-agents-vllm.md) | Zero-cost, auditable local multi-agent stack — vLLM + Tier + Claude Code MCP |

**End-to-end walkthroughs** (each is a complete operational scenario):

| Tutorial | Scenario |
|---|---|
| [t00 — End-to-End Walkthrough](tutorials/t00-bene-e2e-walkthrough.md) | Start here. Spawn → run → checkpoint → audit → restore → export |
| [t01 — Meta-Harness 48% to 83%](tutorials/t01-bene-meta-harness.md) | Automated prompt-strategy search in 15 iterations, $0.14 |
| [t02 — End-to-End Self-Healing](tutorials/t02-e2e-self-healing.md) | Wrong-fix detection, surgical rollback, root cause from audit trail |
| [t03 — Security Swarm](tutorials/t03-security-swarm.md) | 4 parallel auditors, SQL findings aggregation |
| [t04 — Migration Rollback](tutorials/t04-migration-rollback.md) | 2M-row backfill anomaly, 0.3s surgical rollback |
| [t05 — Incident Response](tutorials/t05-incident-response.md) | 12-second root-cause from event journal SQL |
| [t06 — ML Research Lab](tutorials/t06-ml-research-lab.md) | 4 hypothesis agents overnight, SQL-comparable results |
| [t07 — Regression Guard](tutorials/t07-regression-guard.md) | Model swap blocked, Meta-Harness restores baseline |
| [t08 — 100-Agent Scale](tutorials/t08-hundred-agents-scale.md) | 847 agents at scale, hub coordination, 2.45M tokens saved |
| [t10 — Self-Healing CI Overnight](tutorials/t10-ci-overnight-bene-swarm.md) | Regression gate, auto-fix, review and refactor swarms in GitHub Actions |

**Case studies** (real Oppie engagements):

| Case study | Result |
|---|---|
| [cs01 — L1 Recall 98.4% with Opus](case-studies/cs01-bene-triage-rag-harness.md) | Meta-Harness search on Oppie triage retrieval; held-out generalization |
| [cs02 — Self-Healing CI](case-studies/cs02-ci-self-healing-refactor-swarm.md) | Multi-agent CI design, insights, supply-chain practices, cross-team influence |

---

## Use with AI coding tools

After `bene setup`, BENE is available as an MCP tool in Claude Code, Cursor, and other compatible clients. Just describe what you want:

```text
with bene, review my payments module — security agent and test-writing agent in parallel
```

```text
with bene, refactor auth.py — implement, test, and document in parallel
```

```text
with bene, show me all agents that failed in the last run and what errors they hit
```

See [MCP Integration](mcp-integration.md) for setup details.

---

## Key concepts

**Virtual filesystem (VFS)** — each agent has its own isolated filesystem inside the SQLite database. Agents cannot access each other's files. Operations are enforced at the SQL level (`WHERE agent_id = ?`), not by convention.

**Checkpoint** — a snapshot of an agent's files and KV state at a point in time. Restore to any checkpoint in milliseconds. Diff two checkpoints to see exactly what changed. See [Checkpoints](checkpoints.md).

**Audit trail** — every file read, write, tool call, state change, and lifecycle event is recorded as an append-only row in the `events` table. Query with SQL. See [Schema](schema.md).

**Tier router** — the Difficulty-Aware Routing by Tier router classifies task complexity and routes to the right model tier. Trivial → local 7B. Complex → 70B or Claude. See [Architecture](architecture.md).

**Single `.db` file** — the entire runtime is one SQLite file. Copy it to back up. Open it in any SQLite client. Send it to a teammate. No cloud, no server.

---

## Examples

See [`examples/`](../examples/) in the repository root:

- `library_basics.py` — VFS operations without LLMs
- `code_review_swarm.py` — 4 parallel review agents
- `parallel_refactor.py` — implement + test + document simultaneously
- `self_healing_agent.py` — checkpoint + auto-restore on failure
- `autonomous_research_lab.py` — N hypothesis agents with SQL result comparison
- `meta_harness_*.py` — automated prompt/strategy optimization

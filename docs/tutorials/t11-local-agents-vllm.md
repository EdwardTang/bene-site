# t11 — Local Agents with vLLM: a Zero-Cost, Auditable Multi-Agent Stack

*Tutorial · beginner · ~30 min*

---

You will bring up a fully local multi-agent system where Claude Code orchestrates autonomous BENE agents running on your own GPU. Per-agent virtual filesystems, append-only audit trail, checkpoint and rollback, SQL-queryable everything — and zero API cost.

Each step is small. Sections 1–4 stand alone (you can drive BENE from the CLI without Claude Code). Sections 5–9 layer in the MCP integration with Claude Code on top.

![BENE getting started — spawn agents, write files, query VFS](../demos/bene_01_getting_started.gif)

> **At the end of this tutorial, you will have:**
>
> - vLLM serving a 7B model on your GPU (or any OpenAI-compatible endpoint pointed at remotely).
> - BENE configured with Tier routing — single-model, multi-model, or hybrid local/cloud.
> - Claude Code talking to BENE over MCP with all 18 BENE tools registered.
> - One Python "hello world" agent run end-to-end via Claude Code.
> - 3 parallel agents (test-writer / implementer / doc-writer) with per-agent VFS isolation, proven with SQL.
> - A working checkpoint and rollback on a deliberately-broken refactor.
> - A SQL audit trail you can query with `bene query` or any SQLite client.

## Prerequisites

- Linux or macOS workstation.
- One GPU with **≥16 GB VRAM** for a 7B model, or **≥48 GB** (multi-GPU OK) for a 70B model.
- Python ≥3.10 and [`uv`](https://github.com/astral-sh/uv) (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
- ~15 GB free disk (model weights cache in `~/.cache/huggingface/`).
- Claude Code installed locally — only needed for sections 5 onward.

> **Tip.** No local GPU? Sections 1, 3, 4 (cloud-only path) still work — point `endpoint:` at any OpenAI-compatible URL (Together, Anyscale, Fireworks, RunPod, llama.cpp/ollama on a different host). Skip the vLLM bits.

## The architecture in one diagram

```text
┌──────────────────────────────┐
│        Claude Code           │  ← you talk to this (sections 5+)
│  (your terminal / IDE)       │
└─────────┬────────────────────┘
          │ MCP protocol (stdio)
          ▼
┌──────────────────────────────┐
│       BENE MCP Server       │  ← 18 tools: spawn, read, write,
│  agent_spawn, agent_parallel,│     checkpoint, query, pause,
│  agent_checkpoint, mh_search │     resume, mh_search, …
└─────────┬────────────────────┘
          │
          ▼
┌──────────────────────────────┐
│       BENE core + CCR       │  ← isolated VFS, event journal,
│  SQLite, blob store, events  │     checkpoints, blob dedup
└─────────┬────────────────────┘
          │ Tier router (raw httpx)
          ▼
┌──────────────────────────────┐
│           vLLM               │  ← your local GPU(s)
│  Qwen, DeepSeek, Llama, …    │     or any /v1/chat/completions
└──────────────────────────────┘
```

The flow: Claude Code calls BENE tools over MCP. BENE spawns agents into isolated VFSes. The Tier router classifies task complexity and picks the right model. Agents talk to vLLM. Everything is logged in SQLite. Nothing leaves your machine.

> **See also.** [tutorials/t00 — End-to-End Walkthrough](t00-bene-e2e-walkthrough.md) for a spawn → checkpoint → audit → restore round-trip that does **not** need vLLM. Good warm-up: it isolates audit-DB skills from LLM behavior.

## Step 1 — Install BENE (2 min)

```bash
git clone https://github.com/good-night-oppie/bene.git
cd bene
uv sync
uv run bene --version
# bene, version 0.1.0
```

Initialize the database (one of two ways):

```bash
# Interactive wizard — picks a preset, generates bene.yaml, initializes the DB.
uv run bene setup

# Or manually — default config + empty DB.
uv run bene init
# Initialized BENE database: ./bene.db
```

`uv sync` installs all 44 dependencies in under 30 s on first run, single-digit seconds after that. No heavy AI SDK chain — just `httpx`, `click`, `rich`, `textual`, `mcp`, `pyyaml`, `zstandard`, `ulid-py`.

> **Tip.** `bene setup` is the fastest path. It writes `bene.yaml` for you and runs `bene init`. Pick the preset closest to your goal: `local`, `local-multi`, `anthropic`, `openai`, or `hybrid`.

## Step 2 — Start vLLM (5 min, plus first-run download)

vLLM serves models with an OpenAI-compatible API. BENE talks to it via raw `httpx` — no `openai` SDK, no `litellm`.

### Single model — start here

```bash
pip install vllm
vllm serve Qwen/Qwen2.5-Coder-7B-Instruct --port 8000
```

Verify:

```bash
curl http://localhost:8000/v1/models
# Should return JSON listing the served model.
```

> **Tip.** Model weights download into `~/.cache/huggingface/` on first run (~14 GB for the 7B). If you have a fast connection elsewhere, pre-stage with `huggingface-cli download Qwen/Qwen2.5-Coder-7B-Instruct` and the warm path takes seconds.

### Multi-model — recommended if you have ≥48 GB VRAM

```bash
# Terminal 1 — small model for trivial tasks + routing classifier
vllm serve Qwen/Qwen2.5-Coder-7B-Instruct --port 8000

# Terminal 2 — medium model for moderate tasks
vllm serve Qwen/Qwen2.5-Coder-32B-Instruct --port 8001

# Terminal 3 — large model for complex tasks
vllm serve deepseek-ai/DeepSeek-R1-70B --port 8002
```

> **See also.** [tutorials/t06 — ML Research Lab](t06-ml-research-lab.md) shows the same 3-GPU layout running 6 parallel hypothesis agents overnight. The config in the next step is essentially the t06 layout.

### Any OpenAI-compatible endpoint works

BENE speaks raw httpx — anything serving `/v1/chat/completions` is fine:

- **vLLM** (recommended) — fastest batched inference.
- **llama.cpp** / **ollama** — lighter weight, runs on consumer hardware.
- **text-generation-webui** — works if you already have it running.
- **LocalAI** — drop-in OpenAI replacement.
- Remote OpenAI-compatible providers — Together, Fireworks, Anyscale, RunPod, etc.

Point `endpoint:` at the URL.

## Step 3 — Configure BENE (3 min)

If `bene setup` wrote your `bene.yaml`, skim this section and jump to the sanity check at the end. Otherwise, copy and edit:

```bash
cp bene.yaml.example bene.yaml
```

### Single-model

```yaml
database:
  path: ./bene.db
  wal_mode: true
  compression: zstd

models:
  qwen2.5-coder-7b:
    vllm_endpoint: http://localhost:8000/v1
    max_context: 32768
    use_for: [trivial, moderate, complex, critical]

router:
  fallback_model: qwen2.5-coder-7b
  context_compression: true

ccr:
  max_iterations: 50
  checkpoint_interval: 10
  max_parallel_agents: 4
```

### Multi-model

```yaml
database:
  path: ./bene.db
  wal_mode: true
  compression: zstd

models:
  qwen2.5-coder-7b:
    vllm_endpoint: http://localhost:8000/v1
    max_context: 32768
    use_for: [trivial, code_completion]

  qwen2.5-coder-32b:
    vllm_endpoint: http://localhost:8001/v1
    max_context: 131072
    use_for: [moderate, code_generation]

  deepseek-r1-70b:
    vllm_endpoint: http://localhost:8002/v1
    max_context: 131072
    use_for: [complex, critical, planning]

router:
  classifier_model: qwen2.5-coder-7b   # the small model classifies task complexity
  fallback_model: deepseek-r1-70b       # the big model is the safety net
  context_compression: true

ccr:
  max_iterations: 100
  checkpoint_interval: 10
  max_parallel_agents: 8
```

How Tier routes:

1. A task arrives. BENE asks the `classifier_model` (the 7B) "trivial, moderate, complex, or critical?"
2. The router picks a model whose `use_for` contains the classified complexity.
3. If the classifier itself fails, a keyword heuristic takes over (`refactor`, `security`, `format`, …).
4. If the chosen model fails, the request falls through to `fallback_model`.

> **Tip.** The classifier only needs to be smart enough to label tasks. A 7B is plenty and stays warm in VRAM. Reserve the 70B for actual work, not for "is this hard?"

### Hybrid — local + cloud

Route trivial tasks to a free local GPU and only escalate to a cloud model when the work needs it.

```yaml
models:
  claude-sonnet:
    provider: anthropic
    model_id: claude-sonnet-4-20250514
    api_key_env: ANTHROPIC_API_KEY
    max_context: 200000
    use_for: [complex, critical]
  gpt-4o:
    provider: openai
    model_id: gpt-4o
    api_key_env: OPENAI_API_KEY
    max_context: 128000
    use_for: [moderate]
  local-qwen:
    provider: local
    endpoint: http://localhost:8000/v1
    max_context: 32768
    use_for: [trivial]

router:
  classifier_model: local-qwen
  fallback_model: claude-sonnet
  context_compression: true
```

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

> **Tip.** Hybrid pays off when trivial volume is high. Route 80 % of "rename this variable" calls to the free local model and 20 % of hard ones to Claude — your monthly bill drops by roughly the same ratio. Measure before tuning: the Tier router records classifier output in the event journal, and a query against the `events` table tells you the actual split, not the assumed one.

### Cloud-only

If you have no GPU at all, skip vLLM. Use the `anthropic`, `openai`, or `hybrid` preset and point everything at the cloud endpoint.

### Sanity check

```bash
uv run bene run "Say hello and list the tools available to you" --name test-agent
```

You should see structured agent output and a populated `bene.db`. If yes, the model + BENE stack is wired.

## Step 4 — Connect to Claude Code (3 min)

Register BENE as an MCP server so Claude Code can call all 18 BENE tools natively.

### Add to Claude Code settings

`~/.claude/settings.json` (create the file if missing):

```json
{
  "mcpServers": {
    "bene": {
      "command": "uv",
      "args": [
        "run",
        "--project", "/path/to/your/bene",
        "bene", "serve", "--transport", "stdio",
        "--config-file", "/path/to/your/bene/bene.yaml"
      ]
    }
  }
}
```

Replace `/path/to/your/bene` with your clone path.

If you installed BENE globally (`uv tool install .`):

```json
{
  "mcpServers": {
    "bene": {
      "command": "bene",
      "args": ["serve", "--transport", "stdio"]
    }
  }
}
```

### Verify the connection

Restart Claude Code, then ask:

> *"What BENE tools are available?"*

Claude Code should list all 18: `agent_spawn`, `agent_spawn_only`, `agent_read`, `agent_write`, `agent_ls`, `agent_status`, `agent_kill`, `agent_pause`, `agent_resume`, `agent_checkpoint`, `agent_restore`, `agent_diff`, `agent_checkpoints`, `agent_query`, `agent_parallel`, `mh_search`, `mh_frontier`, `mh_resume`.

> **Tip.** If the MCP wiring fails, the fastest split is to run the server standalone first: `uv run --project /path/to/bene bene serve --transport stdio`. If that starts cleanly, the bug is in `settings.json` (most often a JSON syntax error). If it fails standalone, the bug is in BENE or `bene.yaml`.

## Step 5 — Your first agent (2 min)

In Claude Code:

> *"Use BENE to spawn an agent called 'hello-world' that writes a Python hello world program to /src/main.py."*

Behind the scenes:

1. Claude Code calls `agent_spawn` with `name="hello-world"` and the task.
2. BENE creates an agent with a fresh, isolated VFS.
3. The Tier router classifies "trivial" and routes to the 7B.
4. The agent runs a plan-act-observe loop: decide → call `fs_write` to create `/src/main.py` → check the result → return.
5. Every step is logged to the `events` table.

Read it back:

> *"Read the file /src/main.py from the hello-world agent."*

See the timeline:

> *"Show me the event timeline for the hello-world agent."*

Claude Code calls `agent_query`:

```sql
SELECT timestamp, event_type, payload FROM events
WHERE agent_id = '...' ORDER BY event_id;
```

You see every action: `agent_spawn`, `file_write`, `tool_call_start`, `tool_call_end`, `agent_complete`.

> **See also.** [tutorials/t00 — End-to-End Walkthrough](t00-bene-e2e-walkthrough.md) walks the same spawn → read → audit loop without an LLM. Good for grokking the audit DB shape before you also have to interpret model output.

## Step 6 — Parallel agents, the real power (5 min)

![Parallel agents and the Tier router — 3 agents running concurrently](../demos/bene_03_parallel_agents.gif)

In Claude Code:

> *"Use BENE to run 3 agents in parallel:*
> *1. 'test-writer' — write unit tests for a REST payments endpoint.*
> *2. 'implementer' — implement the REST payments endpoint.*
> *3. 'doc-writer' — write API documentation for the payments endpoint."*

What happens:

1. Claude Code calls `agent_parallel` with 3 tasks.
2. BENE spawns 3 agents, each with its own isolated VFS.
3. Tier routes each to the appropriate model based on classified complexity.
4. All 3 run concurrently, bounded by the semaphore (default 8).
5. Auto-checkpoints every 10 iterations.

### See per-agent token cost

> *"How many tokens did each agent use?"*

```sql
SELECT a.name, SUM(tc.token_count) AS tokens, COUNT(tc.call_id) AS calls
FROM agents a LEFT JOIN tool_calls tc ON a.agent_id = tc.agent_id
GROUP BY a.agent_id ORDER BY tokens DESC;
```

### See per-agent files

> *"Show me the files each agent created."*

```sql
SELECT a.name, f.path FROM files f
JOIN agents a ON f.agent_id = a.agent_id
WHERE f.deleted = 0 ORDER BY a.name, f.path;
```

The key insight: **each agent wrote to `/src/payments.py` or `/tests/test_payments.py` — there is no conflict** because each agent has its own namespace. Isolation is enforced at the SQL level, not by convention.

> **Tip.** Default `max_parallel_agents: 8`. Bump it carefully — every running agent holds GPU memory for its KV cache. Multi-GPU vLLM with tensor parallelism lifts the ceiling at the cost of per-request latency.

> **See also.** [tutorials/t03 — Security Swarm](t03-security-swarm.md) uses the same role-split pattern and proves zero cross-agent reads with a single SQL query. Anchor for "isolation is real, not a convention."

## Step 7 — Checkpoint, restore, and debug (5 min)

![Checkpoints and rollback — checkpoint before risky operations, restore on failure](../demos/bene_02_checkpoints.gif)

### Scenario: safe refactor with rollback

> *"Use BENE to: (1) spawn an agent 'refactorer'. (2) Write this code to /src/auth.py: [paste code]. (3) Checkpoint with label 'original'. (4) Have it refactor to add error handling."*

After the agent runs, if the refactor went sideways:

> *"The refactor doesn't look right. Restore the refactorer agent to the 'original' checkpoint."*

Claude Code calls `agent_restore`. The VFS rolls back exactly to its pre-refactor state. No other agents are affected.

### Diff two checkpoints

> *"Show me what changed between the 'original' checkpoint and the current state."*

Claude Code calls `agent_diff`, which returns:

- Files added, removed, or modified (by content hash).
- State changes (KV pairs added, removed, modified — before and after values).
- Tool calls made between the two checkpoints.

This is time-travel debugging — you see exactly what the agent did, step by step, and undo it without disturbing any sibling agent.

> **See also.** [tutorials/t02 — End-to-End Self-Healing](t02-e2e-self-healing.md) — wrong-fix detection, surgical rollback, root cause from the audit trail in one worked example. Per-agent restore in 0.3 s.

## Step 8 — Post-mortem when something breaks (3 min)

![Post-mortem debugging — SQL audit trail, log search, checkpoint diff](../demos/bene_uc03_post_mortem_debug.gif)

> *"Show me all failed tool calls across all agents."*

```sql
SELECT a.name, tc.tool_name, tc.error, tc.timestamp
FROM tool_calls tc JOIN agents a ON tc.agent_id = a.agent_id
WHERE tc.status = 'error'
ORDER BY tc.timestamp DESC;
```

> *"Show me the full event timeline for the failed agent."*

```sql
SELECT timestamp, event_type, payload FROM events
WHERE agent_id = '...' ORDER BY event_id;
```

> *"Which agent used the most tokens?"*

```sql
SELECT a.name, SUM(tc.token_count) AS tokens
FROM agents a JOIN tool_calls tc ON a.agent_id = tc.agent_id
GROUP BY a.agent_id ORDER BY tokens DESC LIMIT 5;
```

> *"What files did the rogue agent modify?"*

```sql
SELECT path, version, modified_at FROM files
WHERE agent_id = '...' AND deleted = 0
ORDER BY modified_at;
```

You can also use the CLI directly:

```bash
uv run bene query "SELECT name, status FROM agents"
uv run bene query "SELECT event_type, COUNT(*) FROM events GROUP BY event_type"
```

Or open `bene.db` in any SQLite client (DBeaver, DataGrip, `sqlite3` CLI) and explore.

> **See also.** [tutorials/t05 — Incident Response](t05-incident-response.md) walks the same SQL patterns at root-cause speed — 12 seconds from incident to fix candidate. Reuse those queries in your runbook.

## Step 9 — The live dashboard (1 min)

```bash
uv run bene dashboard
```

A Textual-based terminal UI shows agents and their status (running, completed, failed, killed), live updates, and an event stream. Useful when running parallel agents and you want to watch progress without piping `SELECT` queries.

## What you got for free

| Capability | How |
|---|---|
| Multi-agent orchestration | Claude Code + BENE MCP tools |
| Agent isolation | Per-agent VFS, SQL-enforced |
| Intelligent routing | Tier classifies tasks → right model |
| Parallel execution | Up to 8 concurrent agents (configurable) |
| Checkpoint and restore | Snapshot + rollback any agent |
| Full audit trail | Append-only event journal, 14 event types |
| SQL-queryable everything | Token usage, errors, files, events |
| Content deduplication | SHA-256 blobs, zstd-compressed |
| Single-file runtime | `cp bene.db backup.db` = full backup |
| Zero API costs | Everything on your GPU |
| Data stays local | Nothing leaves your machine |

## Configuration reference

### `bene.yaml` — full options

```yaml
database:
  path: ./bene.db              # database file path
  wal_mode: true               # WAL mode for concurrent reads (recommended)
  busy_timeout_ms: 5000        # SQLite busy timeout
  max_blob_size_mb: 100        # max file size in blob store
  compression: zstd            # blob compression: zstd | none
  gc_interval_minutes: 30      # blob garbage-collection interval

isolation:
  mode: logical                # logical (default) | fuse (Linux only)
  fuse_mount_base: /tmp/bene   # FUSE mount-point base (Linux only)
  cgroups:
    enabled: false             # cgroup resource limits (Linux only)
    memory_limit_mb: 4096
    cpu_shares: 1024

models:
  <model-name>:
    provider: local | openai | anthropic       # provider type (default: local)
    vllm_endpoint: http://localhost:8000/v1    # for local provider (legacy key)
    endpoint: http://localhost:8000/v1         # for local provider (new key)
    model_id: gpt-4o                           # for openai / anthropic providers
    api_key_env: OPENAI_API_KEY                # env var containing the API key
    max_context: 32768                         # max context window (tokens)
    use_for: [trivial, moderate, ...]          # complexity levels routed here

router:
  type: tier                    # only tier for now
  classifier_model: <name>      # model that classifies task complexity
  fallback_model: <name>        # fallback when the selected model fails
  context_compression: true     # enable multi-stage context compression
  max_retries: 3                # retry count before giving up

ccr:
  max_iterations: 100           # max agent-loop iterations
  checkpoint_interval: 10       # auto-checkpoint every N iterations
  timeout_seconds: 3600         # agent timeout (1 hour)
  max_parallel_agents: 8        # max concurrent agents

mcp:
  port: 3100                    # SSE transport port
  host: 127.0.0.1               # SSE transport host

logging:
  level: INFO
  file: ./bene.log
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `BENE_DB` | `./bene.db` | database file path |
| `BENE_CONFIG` | `./bene.yaml` | config file path |
| `ANTHROPIC_API_KEY` | — | API key for `provider: anthropic` models |
| `OPENAI_API_KEY` | — | API key for `provider: openai` models |

### Claude Code `settings.json`

```json
{
  "mcpServers": {
    "bene": {
      "command": "uv",
      "args": [
        "run", "--project", "/path/to/bene",
        "bene", "serve", "--transport", "stdio",
        "--db", "/path/to/bene/bene.db",
        "--config-file", "/path/to/bene/bene.yaml"
      ]
    }
  }
}
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Connection refused` on `localhost:8000` | vLLM not running | `vllm serve <model> --port 8000`; `curl /v1/models` to confirm |
| Claude Code does not see BENE tools | Bad `settings.json` syntax or wrong path | Validate JSON; restart Claude Code; run the server standalone to bisect (see Step 4 tip) |
| Agent stuck or never completes | Tool loop or runaway iteration | `uv run bene ls` → `uv run bene kill <id>`; lower `max_iterations` |
| Out of GPU memory | Model too big or too many parallel agents | Smaller model; `--gpu-memory-utilization 0.8` on vLLM; lower `max_parallel_agents`; try a quantized variant (GPTQ, AWQ) |
| `Model not found` | Name in `bene.yaml` does not match what vLLM reports | `curl /v1/models \| jq` and use that exact name |
| Database locked | Multiple writers without WAL mode | Confirm `wal_mode: true`; avoid network filesystems for `bene.db` |
| Context too long | Prompt overflow | Enable `context_compression: true` in router; shorten prompts; raise `max_context` to match what vLLM was started with |

## Next steps

Annotated by what each link gives you fastest:

- [tutorials/t00 — End-to-End Walkthrough](t00-bene-e2e-walkthrough.md) — *spawn → checkpoint → audit → restore in 5 minutes,* without an LLM. Cleanest way to internalize the audit DB shape.
- [tutorials/t02 — End-to-End Self-Healing](t02-e2e-self-healing.md) — *the rollback model.* Per-agent restore in 0.3 s, demonstrated end-to-end.
- [tutorials/t03 — Security Swarm](t03-security-swarm.md) — *role split with proof.* Zero cross-agent reads, anchoring-bias measurements, SQL aggregation.
- [tutorials/t05 — Incident Response](t05-incident-response.md) — *audit-DB SQL patterns* you can paste into your runbook.
- [tutorials/t06 — ML Research Lab](t06-ml-research-lab.md) — *N parallel hypothesis agents overnight.* Where local multi-model orchestration earns its setup cost.
- [tutorials/t10 — Self-Healing CI Overnight](t10-ci-overnight-bene-swarm.md) — *advanced; production CI integration.* GitHub Actions wiring on top of the same primitives.
- [Architecture](../architecture.md), [Schema](../schema.md), [CLI Reference](../cli-reference.md) — the primitive references.
- Runnable examples: [`examples/code_review_swarm.py`](../../examples/code_review_swarm.py), [`examples/parallel_refactor.py`](../../examples/parallel_refactor.py), [`examples/self_healing_agent.py`](../../examples/self_healing_agent.py), [`examples/post_mortem.py`](../../examples/post_mortem.py).

---

*BENE is MIT-licensed and runs entirely locally. No data leaves your machine.*

*GitHub: [github.com/good-night-oppie/bene](https://github.com/good-night-oppie/bene)*

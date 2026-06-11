# How BENE Runs a Full ML Research Lab Overnight with 4 Parallel AI Agents

*ML Research*

*4 BENE AI agents explore orthogonal hypotheses simultaneously — LoRA, Lion optimizer, batch scaling, regularization — each isolated, each auditable. You wake up to a SQL table of results and a clear winner (-19.2% val_loss).*

---

You have one GPU cluster and four competing ideas. You can only run one tonight. Or can you?

The classic ML researcher bottleneck: experiments are serial by default. One hypothesis at a time. Run it, wait, read the loss curve, form the next hypothesis, repeat. A four-hypothesis night takes four nights.

BENE breaks the serialization. Four agents, four isolated copies of `train.py`, four hypotheses running in parallel overnight. You wake up to a SQL table of results and a clear winner.

---

![BENE ML research lab demo — 4 agents running parallel experiments overnight, SQL results table, winner identified](../demos/bene_uc_mllab.gif)

*4 agents spawn at 22:00. scale-explorer finishes first at 00:14. arch-explorer finishes last at 05:47. SQL comparison at 06:00 shows clear winner.*

---

## Inspired by Karpathy's Autoresearch

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch) is a compelling demonstration: one agent, one GPU, given a model training script. The agent modifies `train.py`, runs it, reads the loss curve, and proposes an improvement. It keeps the changes that help, discards the ones that don't, and iterates through the night.

The key insight: ML research is systematic enough to be automated. An agent can read a loss curve and generate a reasonable next hypothesis. The bottleneck isn't intelligence — it's the serial loop.

The BENE version extends this to N agents and N hypotheses running simultaneously. Each agent gets its own isolated VFS copy of the training code. They cannot see each other's modifications. Results are queryable when they finish. The insights compound across searches via the BENE knowledge agent.

### What autoresearch does vs. what BENE adds

| autoresearch | BENE research lab |
|---|---|
| 1 agent, 1 GPU | N agents, N directions, parallel |
| Git commit/reset for checkpoints | Formal checkpoints with diff |
| `results.tsv` for tracking | SQL-queryable event journal |
| Git log for audit trail | 14-event-type append-only journal |
| One `train.py`, modified in place | Each agent has its own isolated copy |
| Manual inspection | `bene query "SELECT ..."` |
| One direction at a time | Architecture, optimizer, scaling, regularization simultaneously |

---

## The Problem: Character-Level Language Model, val_loss = 2.34

Task: improve a character-level language model baseline. The model trains on Shakespeare. Current best: `val_loss = 2.34`. Four hypotheses to test tonight:

- **arch-explorer** — LoRA adapters vs full finetune (hypothesis: parameter efficiency helps small models generalize)
- **optim-explorer** — AdamW vs Lion optimizer (hypothesis: Lion's sign-based updates work better for small LMs)
- **scale-explorer** — batch size 32 vs 128 (hypothesis: larger batches stabilize char-level training)
- **reg-explorer** — dropout 0.1 vs 0.3 (hypothesis: more regularization needed for character-level overfit)

Sequential: 4 nights minimum. Parallel with BENE: one night.

---

## Spawning 4 Isolated Agents

```bash
bene parallel \
  "spawn arch-explorer  --from ./charlm --task lora_vs_full" \
  "spawn optim-explorer --from ./charlm --task adamw_vs_lion" \
  "spawn scale-explorer --from ./charlm --task batch_32_vs_128" \
  "spawn reg-explorer   --from ./charlm --task dropout_01_vs_03"

# [arch-explorer]   spawned  vfs_id=arch-2a1b  status=running
# [optim-explorer]  spawned  vfs_id=opt-5c3d   status=running
# [scale-explorer]  spawned  vfs_id=scl-8e4f   status=running
# [reg-explorer]    spawned  vfs_id=reg-1g7h   status=running
#
# 4 agents training in parallel — 22:00
```

Each agent's `train.py` is in its own VFS. No file conflicts. No race conditions. Agent 1 cannot accidentally overwrite Agent 2's best checkpoint. Fully reproducible — each experiment can be replayed from its exact VFS state.

### Behind the CLI: the Python API

The `bene parallel` command is a thin wrapper over the Python SDK. If you want programmatic control — custom direction prompts, different seed scripts per agent, post-run reduction — drop down to Python.

**Step 1 — define the base training script.** Each agent gets its own isolated copy.

```python
BASE_TRAIN_PY = """
CONFIG = {
    "n_layers": 6,
    "n_heads": 6,
    "d_model": 384,
    "learning_rate": 3e-4,
    "optimizer": "adamw",
    "activation": "gelu",
    "dropout": 0.1,
}

def train(config):
    # ... your PyTorch training loop ...
    return {"val_bpb": val_loss}
"""
```

**Step 2 — define the research directions.** Each direction becomes a BENE agent with a specific research mandate.

```python
DIRECTIONS = [
    {
        "name": "arch-explorer",
        "prompt": "Explore architecture changes: LoRA vs full finetune, layers, "
                  "heads, activations. Try one change at a time. Keep improvements.",
    },
    {
        "name": "optim-explorer",
        "prompt": "Explore optimizer changes: AdamW vs Lion, learning rates, "
                  "weight decay, warmup schedules. Keep improvements.",
    },
    {
        "name": "scale-explorer",
        "prompt": "Explore scaling: batch size 32 vs 128, FFN ratio, head count vs "
                  "head dim. Find the stable configuration.",
    },
    {
        "name": "reg-explorer",
        "prompt": "Explore regularization: dropout rates, weight decay, batch-size "
                  "interactions. Keep improvements.",
    },
]
```

**Step 3 — spawn and run in parallel.**

```python
from bene import Bene
from bene.ccr import ClaudeCodeRunner
from bene.router import TierRouter

db = Bene("research-lab.db")
router = TierRouter.from_config("bene.yaml")
ccr = ClaudeCodeRunner(db, router, checkpoint_interval=5)

for direction in DIRECTIONS:
    agent_id = db.spawn(direction["name"])
    db.write(agent_id, "/train.py", BASE_TRAIN_PY.encode())
    db.checkpoint(agent_id, label="baseline")

results = await ccr.run_parallel(DIRECTIONS)
```

BENE auto-checkpoints every 5 iterations. If an agent crashes at iteration 23, you restore to iteration 20 and lose at most 3 experiments — not the entire night.

### What happens inside each agent

Each agent runs an autonomous keep-or-revert experiment loop:

```text
Agent: arch-explorer
  ├── Reads /train.py
  ├── Changes CONFIG["activation"] = "swiglu"
  ├── Runs experiment → val_bpb = 1.12 (improved from 1.18)
  ├── Keeps the change ✓
  ├── Changes CONFIG["n_layers"] = 8
  ├── Runs experiment → val_bpb = 1.25 (regressed!)
  ├── Reverts the change ✗
  ├── Changes CONFIG["pos_encoding"] = "learned"
  ├── Runs experiment → val_bpb = 1.10 (improved!)
  ├── Keeps the change ✓
  └── ... continues ...

Agent: optim-explorer (running simultaneously, isolated)
  ├── Reads /train.py (its own copy, unaffected by arch-explorer)
  ├── Changes CONFIG["optimizer"] = "lion"
  ├── Runs experiment → val_bpb = 1.05 (big improvement!)
  ├── Keeps the change ✓
  └── ... continues ...
```

The key: **both agents modify `train.py`, but they cannot see each other's changes.** Each has its own VFS. No conflicts. No coordination needed.

---

## Running Overnight — Interleaved Training Loops

```text
[00:14]  scale-explorer   COMPLETE  final_val_loss=2.21  (-5.6%)
         Finding: batch_size=128 stabilizes training. Converges faster.

[01:47]  reg-explorer     COMPLETE  final_val_loss=2.28  (-2.6%)
         Finding: dropout=0.3 marginally helps. Small effect.

[03:31]  optim-explorer   COMPLETE  final_val_loss=2.19  (-6.4%)
         Finding: Lion optimizer wins on this task. Better char-level.

[05:47]  arch-explorer    COMPLETE  final_val_loss=1.89  (-19.2%)
         Finding: LoRA + cosine LR schedule. Clear winner.
```

`scale-explorer` finishes first — batch size is a simpler change. `arch-explorer` finishes last — LoRA requires more iterations to stabilize, and the agent runs two full training cycles to compare.

---

## The SQL Comparison

```sql
SELECT
  agent_name,
  final_val_loss,
  ROUND((2.34 - final_val_loss) / 2.34 * 100, 1) AS improvement_pct,
  train_time_min,
  notes
FROM ml_results
WHERE run_id = 'overnight-2026-04-15'
ORDER BY final_val_loss ASC
```

```text
Agent            val_loss  Improvement  Time    Finding
---------------  --------  -----------  ------  ----------------------------------
arch-explorer    1.89 *    -19.2% *     347min  LoRA + cosine LR schedule
optim-explorer   2.19      -6.4%        191min  Lion optimizer outperforms AdamW
scale-explorer   2.21      -5.6%        74min   batch=128 stabilizes convergence
reg-explorer     2.28      -2.6%        182min  dropout=0.3 marginal improvement

* winner
```

`arch-explorer` wins by a wide margin. val_loss 1.89 — a 19.2% improvement over baseline. The LoRA + cosine LR combination is the clear path forward. Lion optimizer is worth combining with the LoRA result.

### More queries across all agents

The same event journal answers operational questions a TSV file cannot:

```sql
-- How many experiments did each agent run?
SELECT a.name, COUNT(tc.call_id) AS experiments
FROM agents a JOIN tool_calls tc ON a.agent_id = tc.agent_id
WHERE tc.tool_name = 'shell_exec'
GROUP BY a.agent_id;

-- Total compute across all agents
SELECT SUM(token_count) AS total_tokens,
       SUM(duration_ms) / 1000.0 AS total_seconds
FROM tool_calls;

-- Which agent's train.py changed the most?
SELECT a.name, f.version AS modifications
FROM files f JOIN agents a ON f.agent_id = a.agent_id
WHERE f.path = '/train.py'
ORDER BY f.version DESC;

-- What did the best agent actually change? (read its final train.py)
SELECT content FROM files f
JOIN agents a ON f.agent_id = a.agent_id
WHERE a.name = 'arch-explorer' AND f.path = '/train.py';
```

One `.db` file, one query language, one source of truth for the whole lab.

---

## Read the Winner

```text
bene read arch-explorer /results/best_config.md

## Winning Configuration — val_loss = 1.89

### Architecture Changes
- LoRA rank: 8 (r=8, alpha=16)
- Applied to: q_proj, v_proj in all attention layers
- Full finetune baseline: val_loss=2.34 (no improvement)
- LoRA finetune: val_loss=1.89 (19.2% improvement)

### Training Changes
- LR schedule: cosine with warmup (1% warmup steps)
- Peak LR: 3e-4 (was 1e-3 — reduced due to LoRA sensitivity)
- Gradient clip: 1.0 (unchanged)

### Hypothesis confirmed
Parameter-efficient finetuning (LoRA) dramatically outperforms
full finetune on this small character-level model. The reduced
parameter count prevents overfitting on the Shakespeare corpus.
```

---

## Checkpoint and Compound

```bash
bene checkpoint arch-explorer --label winning-lora-config

# Seed the next search from this agent's discoveries
bene mh search \
  -b char_lm \
  --seed-from arch-explorer \
  --model claude-sonnet-4-6 \
  -n 10

# [mh-search] Loading knowledge from arch-explorer...
# [mh-search] Loaded skills: lora_param_efficiency, cosine_lr_warmup
# [mh-search] Seeding with best config: val_loss=1.89
# [mh-search] Search starts from the known frontier, not from scratch
```

The next search doesn't start from baseline 2.34. It starts from 1.89, with the LoRA insight already encoded as a reusable skill. The insights compound. Each overnight run seeds the next.

**The compounding effect:** After 3 overnight runs, the knowledge agent has a library of reusable skills for this architecture. Run 4 starts with a seed pool that would have taken weeks of manual iteration to assemble.

---

## Multi-GPU Orchestration

For larger-scale research, BENE distributes agents across multiple GPUs, each running a different model tier. The Tier router assigns each agent to a specific model via `force_model`, so cheap sweeps run on the small model and creative hypothesis generation runs on the largest model.

![Parallel agents and the Tier router — running multiple hypothesis agents concurrently](../demos/bene_03_parallel_agents.gif)

### 3-GPU setup

```text
GPU 0 — Qwen2.5-Coder-7B    (port 8000) → 2 sweep agents (fast hyperparameter scans)
GPU 1 — Qwen2.5-Coder-32B   (port 8001) → 2 architecture agents (design exploration)
GPU 2 — DeepSeek-R1-70B      (port 8002) → 2 novel research agents (creative hypothesis)
```

### Configuration

```yaml
# bene.yaml
models:
  qwen2.5-coder-7b:
    vllm_endpoint: http://localhost:8000/v1
    max_context: 32768
    use_for: [trivial, sweep]
  qwen2.5-coder-32b:
    vllm_endpoint: http://localhost:8001/v1
    max_context: 131072
    use_for: [moderate, architecture]
  deepseek-r1-70b:
    vllm_endpoint: http://localhost:8002/v1
    max_context: 131072
    use_for: [complex, novel_research]
```

### Running 6 agents across 3 GPUs

```python
# examples/multi_gpu_research.py
from bene import Bene
from bene.ccr import ClaudeCodeRunner
from bene.router import TierRouter

db = Bene("multi-gpu-research.db")
router = TierRouter.from_config("bene.yaml")
ccr = ClaudeCodeRunner(db, router, checkpoint_interval=5)

DIRECTIONS = [
    # GPU 0 — 7B: fast sweeps
    {"name": "lr-sweep",    "prompt": "Sweep learning rates 1e-5 to 1e-2",
     "config": {"force_model": "qwen2.5-coder-7b"}},
    {"name": "batch-sweep", "prompt": "Sweep batch sizes 16 to 256",
     "config": {"force_model": "qwen2.5-coder-7b"}},

    # GPU 1 — 32B: architecture exploration
    {"name": "arch-depth",  "prompt": "Explore deeper architectures (12-24 layers)",
     "config": {"force_model": "qwen2.5-coder-32b"}},
    {"name": "arch-width",  "prompt": "Explore wider architectures (512-2048 d_model)",
     "config": {"force_model": "qwen2.5-coder-32b"}},

    # GPU 2 — 70B: novel research ideas
    {"name": "novel-loss",  "prompt": "Design a novel loss combining contrastive and generative objectives",
     "config": {"force_model": "deepseek-r1-70b"}},
    {"name": "novel-arch",  "prompt": "Propose a novel attention mechanism for long sequences",
     "config": {"force_model": "deepseek-r1-70b"}},
]

for d in DIRECTIONS:
    agent_id = db.spawn(d["name"])
    db.write(agent_id, "/train.py", BASE_TRAIN_PY.encode())
    db.checkpoint(agent_id, label="baseline")

results = await ccr.run_parallel(DIRECTIONS)
```

Each agent is fully isolated. The 7B agents on GPU 0 churn through hyperparameter sweeps quickly, while the 70B on GPU 2 takes longer but produces more creative directions. All results live in one `.db` file, queryable with the same SQL.

---

## The Cost

```text
Approach                   Wall Time  Engineer Time               Hypotheses Tested
-------------------------  ---------  --------------------------  -----------------
Sequential (human-driven)  4 nights   4 × setup + analysis        4
BENE parallel overnight    1 night    30 min setup + 15min review  4
```

Same 4 hypotheses. One night instead of four. No wasted hypotheses — even the weaker results are real data that inform the next search. The machine ran the experiments. You read the results.

---

## Why BENE for autonomous research?

**Isolation that matters.** In autoresearch, there is one `train.py` and the agent modifies it in place. Multiple research directions mean multiple git worktrees or separate directories. BENE gives each agent its own virtual filesystem with zero setup.

**Checkpoints that are not git hacks.** autoresearch uses `git commit` and `git reset`. BENE checkpoints capture files, state, and event watermarks together, and you can diff two checkpoints to see exactly what changed. Restore any agent to any point without affecting the others.

**SQL-queryable everything.** Instead of parsing a TSV file, query all experiments across all agents with SQL. *Which agent found the best loss? How many experiments total? What did the failing agent do wrong?* One query, one answer.

**Portability.** The entire research lab — all agents, all experiments, all results — is one `.db` file. Send it to a colleague. Open it on another machine. Back it up with `cp`.

**Scale.** autoresearch runs about 12 experiments/hour on one GPU. With BENE orchestrating 4 agents across 4 GPUs, you run 48 experiments/hour — each exploring a different direction, all isolated and tracked.

---

The machine ran 4 experiments overnight. You wake up to a SQL table of results and a clear winner. The winning configuration is documented, checkpointed, and ready to apply. The insights are encoded as reusable skills that seed the next search.

That's how research should work.

## Related

- [README](../README.md) — BENE overview and full doc index
- [Use Cases](../use-cases.md) — more real-world patterns
- [Use case: Autonomous Research Lab](../use-cases.md#autonomous-research-lab)
- [Component guide: Cross-Agent Skill Library](../skills.md)
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — the original single-agent pattern
- Runnable examples:
  - [`examples/autonomous_research_lab.py`](../../examples/autonomous_research_lab.py) — single-GPU, 4 agents
  - [`examples/multi_gpu_research.py`](../../examples/multi_gpu_research.py) — 3-GPU, 6 agents
- [tutorials/t11 — Local Agents with vLLM](./t11-local-agents-vllm.md) — setting up vLLM + BENE locally

---

*BENE is MIT-licensed and runs entirely locally. No data leaves your machine.*

*Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch). BENE extends the single-agent loop to N parallel agents with isolated VFS, SQL-queryable results, and persistent knowledge across searches.*

*GitHub: [github.com/good-night-oppie/bene](https://github.com/good-night-oppie/bene)*

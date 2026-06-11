# BENE CLI Reference

All commands support `--json` for structured output (composable with `jq` and agent frameworks).

```bash
bene --json <command>
```

---

## Setup & Init

### `bene setup`

Interactive wizard. Picks a model preset, generates `bene.yaml`, initializes the database, and auto-installs the MCP server into Claude Code.

```bash
bene setup
```

Presets: Claude (Sonnet/Opus), OpenAI (GPT-4o), local vLLM (7B/70B), or custom endpoint.

### `bene init`

Initialize a new database at the default path (`./bene.db`) or a custom path.

```bash
bene init
bene init --db ./my-project.db
```

### `bene demo`

Seed a demo database with realistic agent data and open the web dashboard. No API keys needed.

```bash
bene demo
bene demo --port 9000
bene demo --no-browser
```

Creates `demo.db` with 3 execution waves: code review swarm, parallel refactor, prod triage.

---

## Running Agents

### `bene run`

Spawn and run a single agent.

```bash
bene run "Refactor auth.py to use JWT tokens" --name auth-agent
bene run "Find security vulnerabilities" --name security --db ./project.db
```

Options:

- `--name`, `-n` — agent name (auto-generated if omitted)
- `--db` — database path (default: `./bene.db`)

### `bene parallel`

Run multiple agents simultaneously. Each `-t name "prompt"` pair is one agent.

```bash
bene parallel \
  -t security  "Find vulnerabilities in auth.py" \
  -t tests     "Write unit tests for auth.py" \
  -t docs      "Update API documentation"
```

Options:

- `-t name prompt` — define an agent (repeatable)
- `--db` — database path

---

## Inspecting Agents

### `bene ls`

List all agents with status, file count, and tool call count.

```bash
bene ls
bene ls --db ./project.db
bene --json ls | jq '.[] | select(.status == "failed")'
```

### `bene status`

Detailed status for one agent.

```bash
bene status <agent-id>
bene --json status <agent-id>
```

### `bene logs`

Full conversation log and event timeline for an agent.

```bash
bene logs <agent-id>
bene logs <agent-id> --tail 20    # last 20 events
```

### `bene read`

Read a file from an agent's virtual filesystem.

```bash
bene read <agent-id> /path/to/file
bene read <agent-id> /src/auth.py
```

---

## Checkpoints

### `bene checkpoint`

Create a named snapshot of an agent's files and state.

```bash
bene checkpoint <agent-id> --label "before-migration"
bene checkpoint <agent-id> -l "pre-refactor"
```

### `bene checkpoints`

List all checkpoints for an agent.

```bash
bene checkpoints <agent-id>
bene --json checkpoints <agent-id>
```

### `bene restore`

Roll back an agent to a previous checkpoint. Other agents are unaffected.

```bash
bene restore <agent-id> --checkpoint <checkpoint-id>
```

Get checkpoint IDs from `bene checkpoints <agent-id>`.

### `bene diff`

Show what changed between two checkpoints: files added/removed/modified, state changes.

```bash
bene diff <agent-id> --from <checkpoint-id-A> --to <checkpoint-id-B>
```

---

## Querying

### `bene query`

Run arbitrary SQL against the database.

```bash
bene query "SELECT name, status FROM agents"
bene query "SELECT SUM(token_count) FROM tool_calls"
bene query "SELECT * FROM events WHERE agent_id = 'abc123' ORDER BY timestamp"
```

See [schema reference](schema.md) for all tables.

### `bene search`

Full-text search across all agent files and state.

```bash
bene search "SQL injection"
bene search "ConnectionError" --db ./project.db
bene --json search "keyword" | jq '.results'
```

### `bene index`

Build a `/index.md` file in an agent's VFS summarizing all its files (for faster search).

```bash
bene index <agent-id>
```

---

## Agent Lifecycle

### `bene kill`

Terminate a running agent.

```bash
bene kill <agent-id>
```

### `bene export`

Export a single agent's complete state to a standalone database file.

```bash
bene export <agent-id> --output agent-snapshot.db
```

### `bene import`

Import an agent from an exported database file.

```bash
bene import agent-snapshot.db
```

---

## Dashboard & Monitoring

### `bene ui`

Launch the web dashboard. Opens a browser tab with the Gantt timeline, live event feed, and agent inspector.

```bash
bene ui
bene ui --port 9000
bene ui --db ./project.db --no-browser
```

See [Dashboard guide](dashboard.md) for details.

### `bene dashboard`

Launch the terminal TUI monitor.

```bash
bene dashboard
bene dashboard --db ./project.db
```

---

## MCP Server

### `bene serve`

Start the MCP server (18 tools) for Claude Code and other MCP-compatible clients.

```bash
bene serve --transport stdio       # for Claude Code / most clients
bene serve --transport sse         # HTTP/SSE transport
bene serve --port 8765             # custom port (SSE only)
```

See [MCP integration guide](mcp-integration.md) for setup.

---

## Meta-Harness

Commands for running automated prompt/strategy optimization searches.

```bash
bene mh search -b <benchmark> -n <iterations>   # start a search
bene mh search -b text_classify -n 10 -k 2      # 10 iterations, 2 candidates each
bene mh search -b lawbench -n 20 --background   # run detached
bene mh status <search-id>                       # poll progress
bene mh frontier <search-id>                     # view best harnesses
bene mh knowledge                                # view persistent knowledge base
bene mh resume <search-id>                       # resume interrupted search
```

See [Meta-Harness guide](meta-harness.md) for details.

---

## Global Options

| Flag | Description |
|---|---|
| `--json` | Output structured JSON (auto-enabled when stdout is piped) |
| `--db PATH` | Database file (default: `$BENE_DB` or `./bene.db`) |
| `--version` | Print version |
| `--help` | Help for any command |

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `BENE_DB` | `./bene.db` | Default database path |
| `BENE_CONFIG` | `./bene.yaml` | Config file path |

# Magentic-UI Collaboration Patterns (reference)

Source: [Magentic-UI — Microsoft Research](https://www.microsoft.com/en-us/research/blog/magentic-ui-an-experimental-human-centered-web-agent/) (MIT-licensed prototype, Sept 2025).

Four primitives that lifted GAIA benchmark accuracy from 30.3% → 51.9% with humans intervening on only ~10% of steps. Use as design references when building agent workflows in this codebase — they map well onto GSD planning, voice-jarvis confirms, and the §9 pause-rules in `~/.claude/CLAUDE.md`.

## 1. Co-planning
The agent drafts the plan, the human reviews and edits *before any execution starts*.

- Already implemented as: `gsd-plan-phase` → user approves PLAN.md → `gsd-execute-phase`.
- Gap: Magentic-UI lets the user *edit individual plan steps* in-place; GSD currently re-runs the planner. **Adoption note:** consider an `edit-step` flow on PLAN.md before execution (low priority — current re-plan is acceptable).

## 2. Co-tasking
Real-time visibility into what the agent is doing, with the ability to **pause and take manual control mid-run**.

- Partially implemented: voice notifications + `notify` skill stream progress, and Esc interrupts a turn.
- Gap: no "manual override" handoff that returns control after the user does something themselves. **Adoption note:** the GSD checkpoint protocol covers most of this; no immediate work needed.

## 3. Action guards
Hard-coded approval gates for irreversible actions: payments, tab closes, account changes, money movement.

- Already encoded in CLAUDE.md §9 (financial transactions, force-push, secret commits, irreversible cloud ops).
- Magentic-UI's clarification: action guards are *categorical* and *enumerated up front*, not judgment calls per turn.
- **Adoption note:** the §9 list is the canonical enumeration. Don't expand it casually — every addition raises the friction floor for everything else.

## 4. Plan learning ⭐ highest-value pattern
Completed runs **automatically generate reusable plans** for similar future tasks. The system learns workflows from execution traces.

- Closest existing skill: `gsd-extract_learnings` and `everything-claude-code:continuous-learning-v2`.
- Gap vs. Magentic-UI: those extract *rules/instincts*, not *replayable plans*. Magentic-UI saves a parameterized step-list keyed by task type, replayable on a new instance with substituted variables.
- **Adoption note (highest leverage):** when a Koda Stack run (`/koda-brief` → `/koda-script` → ... → `/koda-publish`) succeeds for a vertical, save the parameterized plan to `.planning/<workspace>/plans/koda-<vertical>.yml` so the next vertical run replays the same step-list with new variables. This is the missing connective tissue between GSD and Koda Stack.

---

## Architecture for reference (don't replicate)

Magentic-UI runs four agents:
- **Orchestrator** (LLM lead, plans + delegates)
- **WebSurfer** (browser actions)
- **Coder** (Docker-sandboxed Python/shell)
- **FileSurfer** (file → markdown converter)

We already cover all four roles via different routes:
- Orchestrator → main Claude Code session + `general-task-agent-orchestration`
- WebSurfer → browser-harness + Playwright MCP + Chrome MCP
- Coder → Bash tool + worktree isolation
- FileSurfer → `defuddle`, `Read`, `enterprise-search:search`

**Don't port their multi-agent architecture** — we already have it differently.
**Do port their plan-learning loop** — we don't.

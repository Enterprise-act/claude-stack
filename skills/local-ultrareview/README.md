# local-ultrareview

A local replication of Claude Code's `/ultrareview` that runs Opus subagents in 3 stages — with full live logs and an implementation plan at the end.

## What it does differently

**Anthropic's /ultrareview** runs parallel agents in the cloud and returns a review doc. You get the output. That's it. No logs, no visibility into what the agents looked at.

**This skill** adds two things:

1. **Live logs** — every agent writes a log file as it works. Open a split terminal and watch the correctness agent, security agent, and architecture agent think in real time.
2. **Implementation plan** — after synthesis, a fourth Opus agent writes an exact plan: files, changes, order of operations. Then asks if you want to apply the fixes.

## How it works

**Stage 1 — Parallel review (3 Opus agents)**
- Correctness agent: logic errors, edge cases, broken assumptions
- Security/performance agent: injection risks, auth issues, N+1 queries, memory leaks
- Architecture agent: coupling, responsibility boundaries, pattern consistency

Each agent writes to `reviews/<PR>-<date>/review-<type>.md` as it works.

**Stage 2 — Synthesis**
One Opus agent reads all three reviews and produces a unified `synthesis.md`.

**Stage 3 — Implementation plan**
One Opus agent reads the synthesis and writes `implementation-plan.md` — exact files, exact changes, exact order.

**Main agent presents the plan and asks:** do you want to apply the fixes?

If yes: makes the changes, then asks if you want to commit, re-PR, or merge.

## Usage

Add `SKILL.md` to your `.claude/skills/local-ultrareview/` directory.

Invoke with:
```
/local-ultrareview PR #<number>
```

or describe the code you want reviewed and the skill will run the full pipeline.

## Requirements

- Claude Code with Opus 4.7 (xhigh effort recommended for Stage 1 agents)
- GitHub CLI (`gh`) for PR operations

## Part of cortextOS

This skill is part of the [cortextOS](https://github.com/grandamenium/cortextos) agent framework.

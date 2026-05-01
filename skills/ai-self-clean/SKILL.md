---
name: ai-self-clean
description: Use when setting up automated codebase hygiene — dead code removal, broken-branch triage, or pattern-drift detection. Triggers on "self-cleaning", "slop cleaner", "/heal", "/drift", "auto cleanup codebase", "dead code sweep", or requests to schedule nightly maintenance of a repo. Implements three sequential workflows run on a scheduler, writing to side branches only — humans retain merge authority.
metadata:
  version: 1.0.0
  source: "buildthisnow.com/blog/real-examples/2026-04-17-ai-cleans-itself"
---

# AI Self-Cleaning Codebase

Three workflows, one scheduler, zero auto-merges.

## Safety rails (non-negotiable)

- Every change lands on a **side branch**, never main
- Each workflow writes **regression tests BEFORE** it mutates code
- Final merge authority stays with a human
- Nothing ships unless tests pass

This satisfies the project lifecycle gate: these run on LIVE projects only, triggered by the user explicitly scheduling them — never enabled-by-default during DEV.

## Workflow 1 — `/slop-cleaner` (dead code removal)

Sequence:
1. Write regression tests covering current behavior (snapshot routes, import graphs, type exports)
2. Identify candidates: unused imports, unreferenced types, orphaned routes, unreached branches
3. Delete candidates on a side branch
4. Re-run tests
5. If any test fails → revert that specific deletion, continue with the rest
6. Open PR with diff and test evidence

Verified example: 412 lines removed, "zero tests broke, zero pages stopped rendering."

## Workflow 2 — `/heal` (broken-branch fixer)

Sequence:
1. Identify failing checks on recent PRs/branches (not main)
2. Make **minimal edits** to fix each check — no refactors, no scope creep
3. Score confidence 0–100 based on whether the fix touches only the failing path
4. Email a verdict: files changed, confidence score, suggested merge action
5. Hand control back to the original PR author

Never edits main directly. Never force-pushes. Never auto-merges.

## Workflow 3 — `/drift` (pattern divergence detector)

Sequence:
1. Build a **pattern map** from the last N features: folder layout, filenames, function names, import conventions
2. Identify outliers: files that violate the inferred patterns
3. **Flag, do not rewrite** — drift is sometimes intentional
4. Produce a report, not a PR

Human decides whether each flagged outlier is a mistake or a deliberate evolution.

## Scheduling

One cron/launchd entry runs all three in sequence nightly:

```
slop-cleaner → /heal → /drift
```

Each workflow writes to a shared log file. At the end, the scheduler emails one assembled report: what was deleted, what was healed, what drifted.

**No cloud infrastructure required** — standard crontab or macOS launchd is enough.

## Setup checklist

- [ ] Project is LIVE (per CLAUDE.md lifecycle gate)
- [ ] Side-branch strategy agreed with team
- [ ] Regression test suite baseline established
- [ ] Email recipient configured for nightly verdict
- [ ] Scheduler entry uses `enabled: false` until user says "go live"
- [ ] Slop-cleaner exclusions list seeded (vendored code, generated files)

## When NOT to use

- DEV-stage projects (no stable baseline)
- Repos without a test suite (slop-cleaner needs safety net)
- Shared/protected branches (only operates on side branches)
- Monorepos where pattern drift is intentional per-package (run `/drift` per-package, not repo-wide)

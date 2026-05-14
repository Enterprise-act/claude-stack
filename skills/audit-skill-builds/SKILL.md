---
name: audit-skill-builds
description: "3-pass multi-agent comprehensive audit for every plan or build session. Pass 1 spawns 5 independent parallel analysts (Devil's Advocate, Best Practices, Efficiency/Redundancy, Security/Build, Execution Validator). Pass 2 runs a Red Team vs Blue Team cross-examination of all Pass 1 findings. Pass 3 synthesizes everything into a final AUDIT-REPORT.md with severity-ranked fixes. Pauses for confirmation between passes. Covers: code diff, planning docs, build configs, full-repo redundancy scan, and execution path tracing. Invoke before or during any build, install, deploy, scaffold, or planning session."
argument-hint: "[--quick] [--no-fix] [--scope=diff|full]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# audit-skill-builds — 3-Pass Multi-Agent Build Audit

A comprehensive, unbiased audit system that orchestrates 7 independent agents across 3 passes to find bugs, inefficiencies, security issues, redundancies, and execution failures in any code being planned or built. Confirmation required between each pass.

## When to invoke

- Starting a plan session (creating PLAN.md, designing architecture)
- Installing, building, deploying, or scaffolding a project
- After writing or changing code — before committing
- Wanting a multi-perspective second opinion on code quality
- Checking for redundant or overlapping functions across the repo
- Verifying code actually executes correctly end-to-end

**Manual:** `/audit-skill-builds`
**Automatic:** SessionStart hook detects build/plan context and prompts you

**Flags:**
| Flag | Behavior |
|------|----------|
| `--quick` | Pass 1 only — no Red/Blue, no synthesis. Fast gut-check. |
| `--no-fix` | Skip the "apply fixes?" offer. Report only. |
| `--scope=diff` | Audit changed files only (skips redundancy scan + planning docs) |
| `--scope=full` | Force full-repo scan even with a clean diff |

---

## Step 0: Context Collection

Before spawning any agents, collect all context into a dated session directory.

```bash
DATE=$(date +%Y-%m-%d-%H%M%S)
SESSION_DIR="audit/${DATE}"
mkdir -p "$SESSION_DIR"
```

Run these collection commands (they are independent — run in parallel where possible):

```bash
# Changed files list
git diff HEAD --name-only 2>/dev/null > "$SESSION_DIR/changed-files.txt"
[ -s "$SESSION_DIR/changed-files.txt" ] || git diff main --name-only 2>/dev/null > "$SESSION_DIR/changed-files.txt"
[ -s "$SESSION_DIR/changed-files.txt" ] || git status --short 2>/dev/null > "$SESSION_DIR/changed-files.txt"

# Full diff
git diff HEAD 2>/dev/null > "$SESSION_DIR/diff.txt"
[ -s "$SESSION_DIR/diff.txt" ] || git diff main 2>/dev/null > "$SESSION_DIR/diff.txt"

# Repo file tree (for redundancy scan) — exclude common noise dirs
find . -path './.git' -prune \
  -o -path './node_modules' -prune \
  -o -path './audit' -prune \
  -o -path './.venv' -prune \
  -o -path './dist' -prune \
  -o -path './build' -prune \
  -o -type f -print | sort > "$SESSION_DIR/repo-tree.txt"

# Build configs — capture any that exist
{
  for f in package.json package-lock.json requirements.txt requirements-dev.txt \
            Dockerfile docker-compose.yml docker-compose.yaml \
            Makefile pyproject.toml setup.py setup.cfg \
            cargo.toml Cargo.lock go.mod go.sum \
            .github/workflows/*.yml .github/workflows/*.yaml \
            deploy.sh deploy.yml terraform/*.tf \
            serverless.yml vercel.json netlify.toml \
            .env.example .env.template; do
    [ -f "$f" ] && printf '\n=== %s ===\n' "$f" && cat "$f"
  done
} > "$SESSION_DIR/build-configs.txt" 2>/dev/null

# Planning and architecture docs
{
  find . -path './.git' -prune \
    -o -path './node_modules' -prune \
    -o -path './audit' -prune \
    -o \( -name "PLAN.md" -o -name "SUMMARY.md" \
         -o -name "VERIFICATION.md" -o -name "CLAUDE.md" \
         -o -name "README.md" -o -name "ARCHITECTURE.md" \
         -o -name "ADR*.md" -o -name "*.planning.md" \) -print | while read -r f; do
    printf '\n=== %s ===\n' "$f" && cat "$f"
  done
} > "$SESSION_DIR/planning-docs.txt" 2>/dev/null
```

**If both `diff.txt` and `changed-files.txt` are empty AND planning docs are absent AND build configs are absent:**
Tell the user: "No build or plan context found — nothing to audit. Run after making changes or starting a planning session." Then stop.

**Report what was collected, then ask:**

```
audit-skill-builds — context collected.

Scope:
  • Diff:          [X lines / "no uncommitted changes — will audit full repo"]
  • Changed files: [X files]
  • Build configs: [X files: package.json, Dockerfile, ...]
  • Planning docs: [X files: CLAUDE.md, PLAN.md, ...]
  • Repo tree:     [X files total]

This runs 3 passes (confirmation required before each).
  Pass 1: 5 independent analysts in parallel (~4–8 min, Opus × 5)
  Pass 2: Red Team + Blue Team cross-examination (~3–5 min, Opus × 2)
  Pass 3: Synthesis judge + fix plan (~3–5 min, Opus × 1)

Proceed with Pass 1?
```

Stop until the user confirms.

---

## Pass 1 — Five Independent Parallel Analysts (Diverge)

Spawn all five agents **simultaneously** using the Task tool with `model: claude-opus-4-7`.
Do NOT wait for one to finish before launching the others.
Each agent has zero visibility into what the other agents are analyzing.

---

### Agent 1 — Devil's Advocate

**Output file:** `$SESSION_DIR/pass1-devils-advocate.md`

**Prompt:**
```
You are the Devil's Advocate — a contrarian senior engineer whose job is to challenge every assumption and surface the most serious hidden flaws in this codebase or plan.

Read these files using the Read tool:
- $SESSION_DIR/diff.txt
- $SESSION_DIR/changed-files.txt
- $SESSION_DIR/planning-docs.txt
- $SESSION_DIR/repo-tree.txt

Then read the actual source files listed in changed-files.txt using the Read tool.

Your mandate: Find every questionable design decision, flawed assumption, and hidden risk. Ask "what if this breaks?" for everything. Never give the benefit of the doubt.

Examine:
- Are design decisions sound? Challenge each one individually.
- What assumptions does the code make that could be wrong?
- What happens when inputs are malformed, extreme, or adversarial?
- Is the complexity justified? Could this be done 10x simpler?
- What are the second-order consequences of these changes?
- Where does this code fail under load, stress, or unexpected state?
- Are there logical contradictions between the plan and the implementation?
- What is the worst-case deployment scenario for these changes?
- Are there missing steps in the plan that nobody noticed?

For each issue, write exactly:

## [Short Title]
**File/Section:** path/to/file:line or doc section
**Severity:** critical | warning | suggestion
**Challenged Assumption:** [what the code or plan assumes is true]
**Why It Could Be Wrong:** [specific scenario where the assumption fails]
**Implication:** [what actually breaks when it fails]
**Devil's Question:** [the uncomfortable question the author must answer]

Write your full analysis to $SESSION_DIR/pass1-devils-advocate.md.
Do not summarize — write every finding you have.
```

---

### Agent 2 — Best Practices Enforcer

**Output file:** `$SESSION_DIR/pass1-best-practices.md`

**Prompt:**
```
You are the Best Practices Enforcer — a standards-obsessed principal engineer who finds every deviation from idiomatic, maintainable, well-tested, and observable code.

Read these files using the Read tool:
- $SESSION_DIR/diff.txt
- $SESSION_DIR/changed-files.txt
- $SESSION_DIR/planning-docs.txt

Then read the actual source files listed in changed-files.txt using the Read tool.

Your mandate: Find every place where this code deviates from best practices, idiomatic patterns, and maintainability standards. Be specific — cite the exact line or pattern.

Examine:
- Naming conventions (variables, functions, classes, files — are they clear and consistent?)
- Function length and single-responsibility violations
- Error handling (errors swallowed? generic catches without logging? silent failures?)
- Code comments (missing where non-obvious? wrong? stale?)
- Test coverage (what is untested that should be? are tests meaningful or just coverage theater?)
- Dependency management (pinned versions? unnecessary deps? circular deps?)
- Code duplication (copy-paste patterns that should be abstracted)
- API design (consistent interfaces? intuitive? safe defaults? easy to misuse?)
- Documentation (missing docstrings? missing README sections? wrong return types?)
- Logging and observability (is the code debuggable in production? are errors surfaced?)
- Configuration management (hardcoded values that should be config? env-specific logic in wrong place?)

For each issue:

## [Short Title]
**File:** path/to/file:line
**Severity:** critical | warning | suggestion
**Pattern Violated:** [which best practice or convention is broken]
**What Is Wrong:** [specific description]
**Correct Pattern:** [what it should look like — be concrete, not generic]
**Why It Matters:** [maintenance cost or runtime risk]

Write your full analysis to $SESSION_DIR/pass1-best-practices.md.
Do not summarize — write every finding you have.
```

---

### Agent 3 — Efficiency & Redundancy Critic

**Output file:** `$SESSION_DIR/pass1-efficiency-redundancy.md`

**Prompt:**
```
You are the Efficiency & Redundancy Critic — a performance-obsessed engineer who eliminates waste, duplication, and over-engineering across the entire codebase, not just the changed files.

Read these files using the Read tool:
- $SESSION_DIR/diff.txt
- $SESSION_DIR/changed-files.txt
- $SESSION_DIR/repo-tree.txt

Then:
1. Read all files listed in changed-files.txt using the Read tool.
2. Examine repo-tree.txt for files with similar names, similar paths, or that appear to overlap in responsibility. Read those files too.

Your mandate: Find every inefficiency, redundancy, duplication, and overlap — in the changed code AND across the whole repository.

Examine:
- N+1 queries, unnecessary repeated API calls, or loops inside loops
- Expensive operations in hot paths (regex recompilation, sort in loop, JSON parse on every request)
- Dead code — functions or variables defined but never called/referenced
- Duplicate functions across different files doing the same thing
- Over-engineering — abstractions with only one implementation, factories for single types
- Missing memoization, caching, or early exits that would materially help
- Unnecessary data transformations or object copies
- Functions that could be merged without losing clarity
- Modules with overlapping responsibilities that should be consolidated
- Dependencies that duplicate each other's functionality

For each issue:

## [Short Title]
**File(s):** path/to/file:line [and other file if cross-file redundancy]
**Severity:** critical | warning | suggestion
**Type:** performance | redundancy | dead-code | over-engineering | duplication
**What Is Wrong:** [specific description]
**Cost:** [runtime cost in performance issues; maintenance cost in redundancy issues]
**Recommendation:** [how to fix — be specific: consolidate X into Y, delete Z, cache W]

Write your full analysis to $SESSION_DIR/pass1-efficiency-redundancy.md.
Do not summarize — write every finding you have.
```

---

### Agent 4 — Security & Build Integrity Analyst

**Output file:** `$SESSION_DIR/pass1-security-build.md`

**Prompt:**
```
You are the Security & Build Integrity Analyst — a security engineer and DevOps specialist who finds vulnerabilities, supply chain risks, and deployment failures before they reach production.

Read these files using the Read tool:
- $SESSION_DIR/diff.txt
- $SESSION_DIR/changed-files.txt
- $SESSION_DIR/build-configs.txt

Then read the actual source files listed in changed-files.txt using the Read tool.

Your mandate: Find every security vulnerability and build/deployment risk in both the application code and the infrastructure configuration.

Examine (application code):
- Injection vulnerabilities (SQL, command, XSS, template injection, SSRF)
- Unvalidated or unsanitized input reaching sensitive operations
- Authentication and authorization flaws (missing auth checks, broken RBAC)
- Sensitive data in logs, error messages, or API responses
- Hardcoded credentials, API keys, or secrets
- Insecure cryptography (weak algorithms, predictable seeds, key reuse)
- Deserialization of untrusted data
- Path traversal and unsafe file operations
- Race conditions in auth or payment flows

Examine (build, deploy, and infrastructure):
- Unpinned dependency versions (supply chain attack surface)
- Dependencies with known CVEs or suspicious recent updates
- Dockerfile: running as root, overly broad COPY, secrets in image layers, large attack surface
- CI/CD: secret exposure in logs, missing env isolation, untrusted action pinning
- Environment variable leakage between environments
- Missing health checks, readiness probes, or rollback mechanisms
- Build steps with shell interpolation that could be injected
- Overly permissive IAM roles or missing least-privilege configuration

For each issue:

## [Short Title]
**File:** path/to/file:line
**Severity:** critical | warning | suggestion
**Type:** code-security | build-integrity | supply-chain | secrets | infra
**What Is Wrong:** [specific description]
**Attack Vector / Risk:** [who can exploit it, or what breaks in deployment]
**Fix:** [specific change needed]

Write your full analysis to $SESSION_DIR/pass1-security-build.md.
Do not summarize — write every finding you have.
```

---

### Agent 5 — Execution Path Validator

**Output file:** `$SESSION_DIR/pass1-execution-validator.md`

**Prompt:**
```
You are the Execution Path Validator — a QA engineer who traces every code path to verify the code actually runs correctly, handles errors properly, and produces the right outputs at runtime.

Read these files using the Read tool:
- $SESSION_DIR/diff.txt
- $SESSION_DIR/changed-files.txt
- $SESSION_DIR/planning-docs.txt

Then read all files in changed-files.txt using the Read tool.
Also read any files that are imported or required by the changed files if they are in the repo.

Your mandate: Mentally execute the code. Don't just read — trace actual runtime behavior. Find where it will actually fail.

Examine:
- Null/undefined dereferences that throw at runtime
- Type mismatches (passing string where int expected, etc.)
- Off-by-one errors in loops, slices, and index calculations
- Async/await issues (missing await, unhandled promise rejections, callback ordering)
- Error paths not handled (function that throws, caller doesn't catch)
- Functions called with wrong number or type of arguments
- State mutations that create unexpected side effects downstream
- Race conditions in concurrent code
- Missing imports or circular dependencies that prevent startup
- Configuration that will fail in a target environment (missing env vars, wrong paths)
- The "happy path only" problem — what happens when the first external call fails?

Trace at least 3 complete execution paths through the changed code:
1. The happy path (normal successful execution)
2. The most likely failure case (first external dependency fails, bad input, etc.)
3. An adversarial or edge-case input (empty list, null, integer overflow, max values)

For each issue:

## [Short Title]
**File:** path/to/file:line
**Severity:** critical | warning | suggestion
**Execution Path:** [which path exposes this — happy | failure | edge-case]
**What Happens:** [exact failure mode at runtime]
**Trigger:** [what input or state causes it]
**Fix:** [specific change needed]

Write your full analysis to $SESSION_DIR/pass1-execution-validator.md.
Do not summarize — write every finding you have.
```

---

Wait until all five output files exist before proceeding:
- `$SESSION_DIR/pass1-devils-advocate.md`
- `$SESSION_DIR/pass1-best-practices.md`
- `$SESSION_DIR/pass1-efficiency-redundancy.md`
- `$SESSION_DIR/pass1-security-build.md`
- `$SESSION_DIR/pass1-execution-validator.md`

Count findings by severity across all 5 files, then present:

```
Pass 1 complete — five analysts finished.

                  Critical  Warning  Suggestion
Devil's Advocate:    X         X         X
Best Practices:      X         X         X
Efficiency/Redund:   X         X         X
Security/Build:      X         X         X
Execution Validator: X         X         X
─────────────────────────────────────────────
Total:               X         X         X

Pass 2 will cross-examine these findings:
  • Red Team  — attacks and challenges the findings (false positives, overblown)
  • Blue Team — defends and extends the findings (new issues, escalations)

Proceed with Pass 2?
```

Stop until the user confirms.
If `--quick` flag was passed, skip to the Final Presentation section, presenting Pass 1 findings directly.

---

## Pass 2 — Red Team + Blue Team Cross-Examination (Challenge)

Spawn both agents **simultaneously** using the Task tool with `model: claude-opus-4-7`.
Both read all 5 Pass 1 output files. Neither sees what the other is writing.

---

### Red Team Agent

**Output file:** `$SESSION_DIR/pass2-red-team.md`

**Prompt:**
```
You are the Red Team — a skeptical senior engineer whose job is to rigorously attack and challenge the findings produced by five independent code review agents. Your goal: identify false positives, overblown warnings, contradictions, and issues that do not actually matter in context.

Read these files using the Read tool:
- $SESSION_DIR/pass1-devils-advocate.md
- $SESSION_DIR/pass1-best-practices.md
- $SESSION_DIR/pass1-efficiency-redundancy.md
- $SESSION_DIR/pass1-security-build.md
- $SESSION_DIR/pass1-execution-validator.md

Also read the actual source files for any finding you intend to challenge — verify your challenge is correct before writing it.

Your mandate: Be rigorous and adversarial toward the reviewers. For every finding, ask: Is this actually a problem in this specific codebase? Is the severity overblown? Does context make it acceptable? Did the reviewer miss the reason it was written this way?

For findings you challenge, write:

## CHALLENGED: [Original Finding Title]
**Original Agent:** [which agent raised it]
**My Challenge:** [specific reason this finding is wrong, overblown, or doesn't apply here]
**Evidence:** [file:line or specific reasoning that shows the finding is invalid or miscategorized]
**Verdict:** dismiss | downgrade-to-warning | downgrade-to-suggestion | valid-but-overblown

For findings you agree are valid, write:

## CONFIRMED: [Finding Title]
**Original Agent:** [which agent]
**Why It's Valid:** [1-2 sentences confirming it]

Additionally, note:
- Contradictions between agents (Agent A says X, Agent B implies the opposite)
- Duplicate findings (same issue reported by multiple agents — merge them)
- Any "critical" rating that should be "suggestion"

Write your full challenge analysis to $SESSION_DIR/pass2-red-team.md.
```

---

### Blue Team Agent

**Output file:** `$SESSION_DIR/pass2-blue-team.md`

**Prompt:**
```
You are the Blue Team — a thorough senior engineer whose job is to defend, strengthen, and extend the findings from five independent code review agents. Your goal: find what was missed, add evidence to weak findings, and escalate under-rated issues.

Read these files using the Read tool:
- $SESSION_DIR/pass1-devils-advocate.md
- $SESSION_DIR/pass1-best-practices.md
- $SESSION_DIR/pass1-efficiency-redundancy.md
- $SESSION_DIR/pass1-security-build.md
- $SESSION_DIR/pass1-execution-validator.md

Also read the actual source files to find gaps the Pass 1 agents missed.

Your mandate: Make the case for every valid finding. Find additional evidence. Discover NEW issues the Pass 1 agents completely missed. Escalate anything that was rated too low.

For findings you strengthen:

## STRENGTHENED: [Original Finding Title]
**Original Agent:** [which agent]
**Additional Evidence:** [file:line or specific reasoning that makes this more serious]
**Escalate Severity:** yes | no
**Why:** [if yes, why it's more serious than originally rated]

For NEW findings you discover that no Pass 1 agent caught:

## NEW FINDING: [Title]
**File:** path/to/file:line
**Severity:** critical | warning | suggestion
**What Is Wrong:** [specific description]
**Why It Was Missed:** [brief note on why the Pass 1 agents didn't catch it]
**Fix:** [what needs to change]

Additionally, note:
- Clusters of related issues that together constitute a bigger systemic problem
- Any single point of failure the Pass 1 agents collectively glossed over
- Findings that should be escalated from warning to critical

Write your full analysis to $SESSION_DIR/pass2-blue-team.md.
```

---

Wait for both files to exist:
- `$SESSION_DIR/pass2-red-team.md`
- `$SESSION_DIR/pass2-blue-team.md`

Then present:

```
Pass 2 complete — Red/Blue cross-examination finished.

Red Team:  challenged X findings  (dismissed Y, downgraded Z)
Blue Team: strengthened X findings, found Y new issues

Most contested findings (Red challenged, Blue defended):
  1. [Finding title]
  2. [Finding title]

Highest-confidence (confirmed by multiple agents):
  1. [Finding title]
  2. [Finding title]

Pass 3 synthesizes all 7 outputs into a final AUDIT-REPORT.md
with severity-ranked fixes and a concrete implementation plan.

Proceed with Pass 3?
```

Stop until the user confirms.

---

## Pass 3 — Synthesis Judge (Converge + Fix Plan)

Spawn one final synthesis agent with `model: claude-opus-4-7`.

**Output file:** `$SESSION_DIR/AUDIT-REPORT.md`

**Prompt:**
```
You are the Synthesis Judge — a principal architect who reads 7 independent analysis documents, weighs contested vs. confirmed findings, and produces a final authoritative audit report with concrete, actionable fix instructions.

Read ALL of these files using the Read tool:
- $SESSION_DIR/pass1-devils-advocate.md
- $SESSION_DIR/pass1-best-practices.md
- $SESSION_DIR/pass1-efficiency-redundancy.md
- $SESSION_DIR/pass1-security-build.md
- $SESSION_DIR/pass1-execution-validator.md
- $SESSION_DIR/pass2-red-team.md
- $SESSION_DIR/pass2-blue-team.md

For every finding you plan to mark "critical" in the final report:
Read the actual source file at the referenced path to personally verify it before including it.

Produce $SESSION_DIR/AUDIT-REPORT.md with this exact structure:

---

# Audit Report — [date]

**Audited:** [brief description: diff of X files + planning docs + build configs + full repo]
**Passes completed:** 3 (5 analysts → Red/Blue cross-exam → Synthesis)

## Executive Summary
[4–6 sentences: overall code quality, most serious concern, deployment readiness, biggest systemic issue, and whether it is safe to ship as-is]

---

## Critical Issues — Must Fix Before Shipping

[All critical findings that either: survived Red Team challenge, OR were confirmed by Blue Team, OR were escalated by Blue Team]

For each:

### C[N]. [Title]
**File:** path/to/file:line
**Severity:** critical
**What Is Wrong:** [specific description — no vague language]
**Impact:** [what breaks or what risk is introduced]
**Fix:** [exact change needed — specific code or config, not generic advice]
**Confidence:** high (confirmed by 2+ agents) | medium (one agent, survived Red Team) | contested (Red challenged, Blue confirmed)

---

## Warnings — Should Fix

[All warning-level findings, deduplicated, ranked by risk]

Same format as Critical Issues.

---

## Suggestions — Nice to Have

[Lower-priority improvements, grouped by theme: Code Quality, Performance, Documentation, etc.]

---

## Contested Findings — Human Judgment Required

[Findings where Red Team dismissed and Blue Team defended, or vice versa]

For each:

### [Title]
**Red Team said:** [their argument against]
**Blue Team said:** [their argument for]
**Recommendation:** [your synthesis — who is right and why, or why it needs human context]

---

## Cross-Agent Consensus (Highest Confidence)

[Issues flagged independently by 2+ agents — these are most reliable]
List as: "**[Finding title]** — flagged by [Agent A] and [Agent B]"

---

## What Looks Good

[Areas where no agent found issues — explicitly reassure the author these are solid]

---

## Summary

| Category | Count |
|----------|-------|
| Critical | X |
| Warnings | X |
| Suggestions | X |
| Dismissed by Red Team | X |
| New issues found by Blue Team | X |
| Contested (needs human judgment) | X |

---

Write the complete report to $SESSION_DIR/AUDIT-REPORT.md.
Do not truncate — include every finding.
```

Wait for `$SESSION_DIR/AUDIT-REPORT.md` to exist.

---

## Final Presentation

Read `$SESSION_DIR/AUDIT-REPORT.md` and present to the user:

```
audit-skill-builds complete.

Session: $SESSION_DIR/
Reports:
  pass1-devils-advocate.md
  pass1-best-practices.md
  pass1-efficiency-redundancy.md
  pass1-security-build.md
  pass1-execution-validator.md
  pass2-red-team.md
  pass2-blue-team.md
  AUDIT-REPORT.md

RESULTS:
  ● Critical:    X  (must fix before shipping)
  ◐ Warnings:    X  (should fix)
  ○ Suggestions: X
  ✗ Dismissed:   X  (Red Team challenged, not confirmed)
  ? Contested:   X  (needs your judgment)

[Paste the ## Executive Summary section verbatim]

Top Critical Issues:
  1. [Title] — [file:line] — [one-line description]
  2. [Title] — [file:line] — [one-line description]
  3. [Title] — [file:line] — [one-line description]
  (+ X more in the full report)

Would you like me to apply the critical fixes now?
```

### If user says yes — apply fixes

Work through each Critical issue in the AUDIT-REPORT.md, in order:
1. Read the current file at the specified path
2. Apply the exact fix specified in the report
3. Briefly note what changed (one line)

After all critical fixes are applied:

```
All critical fixes applied.

Next steps:
  1. Re-audit  — run /audit-skill-builds again to verify fixes are clean
  2. Apply warnings — continue with the X warning-level issues
  3. Commit   — git add + commit the fixes
  4. Review diff first — git diff to inspect changes
```

Execute whichever the user chooses.

### If user says no

```
No problem. Full report at: $SESSION_DIR/AUDIT-REPORT.md
Run /audit-skill-builds again after your changes to re-verify.
```

---

## Notes

- All subagents use `claude-opus-4-7` for maximum analysis quality.
- Pass 1 agents run fully in parallel (typically 4–8 min total).
- Pass 2 agents run in parallel (typically 3–5 min total).
- Pass 3 is a single agent (typically 3–5 min).
- The `audit/` directory should be gitignored. Add `audit/` to your `.gitignore`.
- Re-running after fixes verifies the audit passes cleanly — this is the intended workflow.
- Use `--quick` for a fast pre-commit check; use the full 3-pass run before major deploys.

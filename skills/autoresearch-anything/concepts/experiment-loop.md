# The Experiment Loop

This is the core runtime cycle that repeats forever during autonomous operation.

## The 10-Step Cycle

Each cycle is triggered by the configured interval (via /loop cron or GitHub Actions schedule).

### C1. READ CONTEXT

Before forming any hypothesis, the agent reads everything:

- `results.tsv` - full experiment history (what's been tried, what worked)
- `resource.md` - accumulated experimental learnings (positive AND negative)
- `user-knowledge.md` - foundational knowledge from the user (IMMUTABLE)
- `research-findings.md` - foundational research from setup phase (IMMUTABLE)
- `constraints.md` - hard rules that must never be violated (IMMUTABLE)
- Current experiment file - the last known good state
- Current git state - which branch, which commit

### C2. HYPOTHESIZE

All knowledge sources carry equal weight. The agent forms a hypothesis:

- What has been tried before? (results.tsv)
- What has worked? What hasn't? (resource.md)
- What does foundational knowledge suggest? (user-knowledge.md + research-findings.md)
- What do constraints forbid? (constraints.md)

The agent has full freedom to decide WHAT to change and HOW MUCH. No strict one-variable-at-a-time rule. The agent uses its judgment on experiment scope.

### C3. MODIFY

Edit the experiment file with the proposed change. Must respect ALL constraints from constraints.md. Constraint violations make an experiment invalid.

### C4. COMMIT

```bash
git add experiment/{file}
git commit -m "experiment #{N}: {hypothesis description}"
```

The commit message IS the experiment documentation. Be descriptive.

### C5. DEPLOY

```bash
bash connectors/deploy.sh
```

If deploy fails: status="crash", git reset --hard HEAD~1, redeploy previous version, log error, try different approach next cycle.

### C6. WAIT

This cycle ends here. The next cycle fires after the configured interval. During this wait, the measurement window passes and data accumulates.

### C7. MEASURE

At the start of the next cycle, measure the previous experiment:

```bash
bash connectors/measure.sh
```

Parse the standardized output:
```
metric_value: 3.2
sample_size: 150
timestamp: 2026-03-17T08:00:00Z
experiment_id: b2c3d4e
```

### C8. DECIDE

Binary decision. No nuance.

**If metric improved** (in the configured direction, meeting the threshold):
- status = "keep"
- Branch advances (commit stays)
- Write POSITIVE insight to resource.md
- Notify user

**If metric same or worse:**
- status = "discard"
- `git reset --hard HEAD~1`
- Redeploy previous version: `bash connectors/deploy.sh`
- Write NEGATIVE insight to resource.md
- Notify user

**If crash/error:**
- status = "crash"
- `git reset --hard HEAD~1`
- Redeploy previous version
- Log error details

### C9. RECORD

Append to results.tsv (tab-separated):

```
commit    metric_value    sample_size    status    description    timestamp
```

### C10. REPEAT

Loop back to C1. Form next hypothesis. Never stop.

## Compounding Improvements

Each "keep" advances the branch. The next experiment builds on the improved version. Over time, small gains stack. This is Karpathy's exact pattern - the branch represents the best-known state and only moves forward.

## Logging Both Keeps AND Discards

After every experiment, the agent appends to resource.md:

**For keeps:**
```
### Experiment #N - KEEP - {date}
**Hypothesis:** {what was changed and why}
**Result:** {metric} improved from {old} to {new} ({delta})
**Insight:** {why this likely worked, what to build on}
```

**For discards:**
```
### Experiment #N - DISCARD - {date}
**Hypothesis:** {what was changed and why}
**Result:** {metric} went from {old} to {new} ({delta})
**Insight:** {why this likely didn't work, what to avoid}
```

Negative learnings are just as valuable. They prevent the agent from repeating failed approaches and help it understand what the audience/market doesn't respond to.

## Session Management

**On restart** (crash recovery, manual restart): Agent checks for existing `autoresearch/{pipeline-name}/*` branches. If found, continues on the most recent one. Reads results.tsv and resource.md to pick up where it left off.

**New session** (deliberate fresh start): Creates a new branch from the last known good state. Carries forward all knowledge files, resource.md, and results.tsv. Fresh git history for this session's experiments.

## Crash Handling

- **Deploy failure**: Log as crash, revert, try different approach next cycle
- **Measurement failure**: Log as crash, revert, try different approach
- **Trivial bugs** (typo in deploy script, API rate limit): Fix and retry
- **Fundamental issues** (API down, account suspended): Log and alert user

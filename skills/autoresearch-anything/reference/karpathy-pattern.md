# Karpathy's Autoresearch Pattern

Distilled from [karpathy/autoresearch](https://github.com/karpathy/autoresearch) - the original repo that started autonomous AI experimentation.

## The Three-File Architecture

Karpathy's entire system is three files:

| File | Role | Who edits | Business equivalent |
|------|------|-----------|-------------------|
| `prepare.py` | Fixed evaluation function, data loading, constants | Nobody | `connectors/measure.sh` - immutable metric collection |
| `train.py` | The thing being optimized (model, hyperparams, architecture) | The AI agent | `experiment/{file}` - the thing being optimized |
| `program.md` | Instructions for the agent (setup, loop, constraints) | The human | `program.md` - same concept, adapted for business |

The key insight from Karpathy: **"You are not touching any of the Python files like you normally would as a researcher. Instead, you are programming the program.md Markdown files that provide context to the AI agents."**

## The Keep/Discard Loop

From Karpathy's program.md, verbatim:

```
LOOP FOREVER:
1. Look at the git state: the current branch/commit we're on
2. Tune train.py with an experimental idea by directly hacking the code
3. git commit
4. Run the experiment: uv run train.py > run.log 2>&1
5. Read out the results: grep "^val_bpb:|^peak_vram_mb:" run.log
6. If the grep output is empty, the run crashed. Read tail -n 50 run.log
7. Record the results in the tsv
8. If val_bpb improved (lower), you "advance" the branch, keeping the git commit
9. If val_bpb is equal or worse, you git reset back to where you started
```

This is the entire algorithm. Modify, run, measure, keep or discard. Nothing more.

## Branch-as-State

The current branch HEAD is always the best known state. The branch only moves forward (on keep). On discard, git reset rolls back to the previous known-good state. This means:

- The branch IS the accumulated improvement
- Git history IS the experiment log (for keeps)
- Reverting is trivial and atomic
- You can always diff current vs baseline to see total progress

## The NEVER STOP Principle

From Karpathy's program.md:

> "Once the experiment loop has begun, do NOT pause to ask the human if you should continue. Do NOT ask 'should I keep going?' or 'is this a good stopping point?'. The human might be asleep, or gone from a computer and expects you to continue working indefinitely until you are manually stopped. You are autonomous."

The agent runs until interrupted. Period.

## Fixed Measurement Budget

Karpathy fixes training time at exactly 5 minutes. This makes ALL experiments comparable regardless of what the agent changes. The business equivalent: a fixed measurement window (e.g., 24 hours) with fixed conditions (same audience, same volume).

This creates fairness. An experiment measured over 24 hours with 500 sends is comparable to another experiment measured over 24 hours with 500 sends. Without fixed conditions, results are noise.

## The Simplicity Criterion

From Karpathy's program.md:

> "All else being equal, simpler is better. A small improvement that adds ugly complexity is not worth it. Conversely, removing something and getting equal or better results is a great outcome - that's a simplification win."

For business: prefer cleaner, shorter copy over complex multi-paragraph rewrites that barely improve the metric.

## Results Logging

Tab-separated (NOT comma-separated), 5 columns in Karpathy's version:

```
commit    val_bpb    memory_gb    status    description
a1b2c3d   0.997900   44.0         keep      baseline
b2c3d4e   0.993200   44.2         keep      increase LR to 0.04
c3d4e5f   1.005000   44.0         discard   switch to GeLU activation
```

Status values: `keep`, `discard`, `crash`. Our adaptation adds `baseline` and a `timestamp` column.

## Real Results

Karpathy's overnight run: 126 experiments in ~10.5 hours. 23 kept, 102 discarded, 1 crash (18% keep rate). val_bpb improved from 0.9979 to 0.9697. The key takeaway: most experiments fail. That's expected and good. The system's value is in running volume - 100+ experiments overnight while you sleep.

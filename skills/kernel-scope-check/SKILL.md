---
name: kernel-scope-check
description: Scope and clarify ambiguous user requests before executing them. Use this skill whenever the user asks for a creative, analytical, strategic, or multi-step deliverable (write, draft, analyze, compare, strategize, build, design, plan, outline, summarize, research) without clearly specifying audience, format, length, constraints, or success criteria. Use it aggressively — when in doubt, run a scope check rather than guess. Also use when a request is shaped like "help me with X" or "something about Y" or "what's the best approach for Z" without anchors. Do NOT use for simple factual questions, conversational exchanges, code debugging with a stated error, or follow-up iterations where scope was already established. The goal is to run the KERNEL framework (Keep-it-simple, Easy-to-verify, Reproducible, Narrow-scope, Explicit-constraints, Logical-structure) in reverse — identify which dimension is missing and ask 1-3 targeted button-choice questions before producing output. This prevents wasted iteration and produces a better first draft.
---

# KERNEL Scope Check

Before executing any substantive creative, analytical, or multi-step request, mentally run the user's prompt through the KERNEL checklist. If one or more dimensions are materially unspecified AND the gap would change the output meaningfully, ask 1–3 targeted clarifying questions using `ask_user_input_v0` before producing the deliverable.

**Goal is speed, not interrogation.** One round of scoping beats three rounds of revision. But asking when the answer is obvious wastes the user's time too.

## When to run a scope check

Run it when the request has the shape of a deliverable but lacks anchors:

- "Write a..." / "Draft a..." / "Build me a..." / "Design a..."
- "Analyze..." / "Compare..." / "Evaluate..." / "Summarize..."
- "Help me with..." (when ambiguous)
- "What's the best approach for..." (when the answer depends on context)
- Multi-step strategic or creative work
- Anything where you'd have to guess at audience, format, or depth

Skip it for:

- Simple factual questions ("what year did X happen")
- Conversational exchanges ("thanks", "interesting point")
- Code debugging with a stated error or specific failure
- Follow-up iterations where scope was already established earlier in the thread
- Requests where audience, format, length, and constraints are already specified
- When the user explicitly says "just go" / "your best guess" / "don't ask" / "you decide"
- When user memory or project context makes the answer obvious

**Never run a scope check more than once per request.** If scope was established, don't re-ask on follow-ups.

## The KERNEL dimensions to evaluate

Mentally run through these before every substantive request. If 2+ are materially missing AND the gap would change the output, trigger a scope check:

| Letter | Dimension | The question you're silently asking yourself |
|---|---|---|
| **K** | Keep it simple | Is there one clear goal, or could this mean 3 different things? |
| **E** | Easy to verify | Do I know what "success" looks like for this output? |
| **R** | Reproducible | Is the request anchored to specific inputs, versions, named documents? |
| **N** | Narrow scope | Is this one task, or three stacked into one request? |
| **E** | Explicit constraints | Do I know what to avoid (length, tone, topics, format)? |
| **L** | Logical structure | Is the output format specified (memo, table, script, code, slide deck)? |

## How to ask

Use `ask_user_input_v0`. Keep it fast and mobile-friendly:

1. **Brief framing** — one sentence before the tool call: "Quick scope check so I get this right the first time —"
2. **1–3 questions max**, prioritizing the dimensions with the biggest impact on output
3. **2–4 button options per question** — no typing required on mobile
4. **Always include an escape option** — like "just pick for me" or "use your best guess"

### Question priority (ask the highest-impact missing dimension first)

1. **Audience / use context** — who's the reader, where does this go? (changes everything)
2. **Output format** — length, shape, medium (doc, bullets, table, email, script)
3. **Must-include or must-exclude** — constraints that would be painful to discover in revision
4. **Depth** — quick take vs. comprehensive

## Worked examples

**Example 1 — vague deliverable (ASK)**
> User: "Write me something about our onboarding process"

Questions to ask:
- "What's this for?" → [Internal training / External marketing / Sales enablement / New hire orientation]
- "How long?" → [One-pager / 2–5 pages / Full guide / Just an outline first]

**Example 2 — strategic ask (ASK)**
> User: "Can you analyze our partnership program?"

Questions to ask:
- "What decision is this feeding?" → [Should we expand / Should we cut / Should we restructure / Just a health check]
- "Who's reading it?" → [Just me / Leadership team / External partner / Board]

**Example 3 — fully scoped (DON'T ASK)**
> User: "Write a 500-word LinkedIn post for restoration company owners about why partnership programs fail. 3 reasons. Conversational tone."

Audience, length, format, tone, and structure are all specified. Execute.

**Example 4 — factual (DON'T ASK)**
> User: "What's the capital of Peru?"

Just answer.

**Example 5 — follow-up in thread (DON'T ASK)**
> [Earlier: user asked for a partner training script, scope was established]
> User: "Make it more conversational"

Scope is established. Execute the revision.

**Example 6 — "just go" override (DON'T ASK)**
> User: "Write a marketing email for my restoration business. Your call on everything else."

User has explicitly delegated scope. Make assumptions, state them at the top of your response, execute.

## When you decide NOT to scope-check, state assumptions

If you infer scope from context rather than asking, briefly name your assumptions at the top of the output so the user can redirect cheaply:

> "Assuming you want a ~500-word internal memo for your restoration team, not external-facing. Say the word if you want a different direction."

This is a cheap insurance policy — it costs one sentence and prevents a wasted deliverable.

## When the user declines to answer

If the user says "just pick" / "your best guess" / "you decide" / "skip the questions":

- Do NOT ask again
- Make explicit assumptions using their memory / context / prior chat
- State those assumptions at the top of your response
- Produce the deliverable

## Anti-patterns to avoid

- Asking questions whose answers are already in the conversation history or user memory
- Asking more than 3 questions in one scope check
- Asking questions whose answers are easier to correct in revision than to surface upfront
- Serializing questions across multiple turns instead of batching them in one `ask_user_input_v0` call
- Running a scope check on every message in a long thread
- Asking when the user is clearly in flow and wants momentum
- Turning this into a ritual — if the answer is obvious, skip and just execute

## Self-check before triggering

Before calling `ask_user_input_v0`, ask yourself:

1. Would I actually produce a different output depending on their answer? If no → skip, just execute.
2. Can I infer this from context, memory, or the project? If yes → skip, state the assumption.
3. Is this the user's 4th+ message in this thread? If yes → scope is probably established, skip unless something genuinely new is being asked.
4. Would they be annoyed if I asked this? If yes → skip.

If you pass all four, run the scope check.

# The KERNEL Prompting Playbook

A reusable framework for getting reliable AI output on the first try. Adapted from the Reddit post by u/volodith, with the fluff and unverified stats stripped out.

---

## The core idea

Six principles, one mnemonic: **KERNEL**. Each letter is a checkbox. If your prompt fails one of them, fix it before you send.

The framework's value isn't the acronym — it's the discipline of running every prompt through the same checklist.

---

## KERNEL, decoded

### K — Keep it simple
One clear goal. Not 500 words of backstory.

- ❌ "I need help writing something about our partner onboarding process"
- ✅ "Write a 90-second opening script for a restoration partner activation meeting"

### E — Easy to verify
You must be able to tell if the output succeeded. If you can't define success, the AI can't deliver it.

- ❌ "Make it engaging"
- ✅ "Include 3 specific plumber objections and a one-line rebuttal for each"

### R — Reproducible
Avoid time-bound language. Use specific versions, named documents, exact requirements. The same prompt should work in 6 months.

- ❌ "Use current best practices for partner outreach"
- ✅ "Use the handoff mechanics from my 2024 Full Service Pros activation deck"

### N — Narrow scope
One prompt = one deliverable. Split compound asks into a chain.

- ❌ "Write the script, the slide deck, and the follow-up email"
- ✅ Three prompts — each seeded with the output of the prior one

### E — Explicit constraints
Tell the AI what **not** to do. Exclusions cut unwanted output faster than any positive instruction.

- ❌ "Write a tutorial"
- ✅ "Write a tutorial. No promotional language. No external links. No section longer than 200 words."

### L — Logical structure
Every prompt gets four blocks:
1. **Context** — only the background that matters
2. **Task** — one verb-driven sentence
3. **Constraints** — limits, exclusions, format rules
4. **Output** — exact shape of the final product

---

## The template (copy/paste)

```
Context: [1–3 sentences of only the background that matters]
Task: [one verb-driven sentence — write, compare, extract, draft]
Constraints:
  - [what to include / what to exclude]
  - [length, tone, style rules]
  - [what NOT to do]
Output: [exact format — table, bulleted list, 3-paragraph memo, code block]
Verify by: [how I'll know this succeeded]
```

---

## Worked examples from your actual workflows

### Partner activation (restoration)
```
Context: I run partner onboarding for a restoration company. Our partners are
plumbing and HVAC technicians who refer water-damage jobs to us.
Task: Write the 10-minute mid-meeting segment on insurance upsell.
Constraints:
  - Technician-level vocabulary, no insurance jargon
  - Must address "won't this hurt my customer relationship?"
  - No mention of competitors by name
Output: Script with stage directions in [brackets], ~800 words
Verify by: A technician with no sales training can read it cold
```

### DTC 2.0 strategy extraction
```
Context: I'm researching DTC 2.0 frameworks to apply to a B2B referral-partnership model.
Task: Extract the 3 DTC 2.0 principles that translate to partnership economics and ignore the rest.
Constraints:
  - Commit to 3 — no "it depends"
  - Each principle tied to one metric (LTV:CAC, retention, first-party data, etc.)
  - Max 150 words per principle
Output: 3 H2 sections — Principle / Why it translates / One concrete action for Monday morning
Verify by: A non-strategic operator can act on it without follow-up questions
```

### Research synthesis (scheduling problems)
```
Context: I have 12 peptides and need a weekly protocol that avoids pathway overlap.
Task: Build a 7-day schedule that keeps GH-pathway peptides from competing.
Constraints:
  - Only use peptides I named — do not suggest alternatives
  - Flag any pair that competes for the same receptor pathway
  - Structure as a logistical scheduling problem, not medical advice
Output: 7-day table (Mon–Sun) × AM/PM, with conflicts flagged below
Verify by: No two GH-pathway peptides appear in the same 24h window
```

### Drafting legal/formal documents
```
Context: I'm preparing a cooperation report for a U.S. Attorney in support of a substantial assistance motion.
Task: Draft the "nature and extent of cooperation" section.
Constraints:
  - Court-appropriate register — no colloquial language
  - Factual only, no editorial characterization
  - Dates in ISO format, names pseudonymized as [Subject A], [Subject B]
Output: 3–5 numbered paragraphs, ~600 words
Verify by: Could be pasted into a filing with only citation formatting added
```

---

## Pre-flight checklist

Before hitting send, run your prompt through these six:

1. **K** — Under 200 words of setup?
2. **E** — Could a stranger tell if this output succeeded?
3. **R** — Is all language timeless (specific versions, named docs) rather than "latest" or "current"?
4. **N** — Exactly one verb driving the ask?
5. **E** — Did I say what NOT to do?
6. **L** — Is the exact output format specified?

If any answer is no, revise before sending.

---

## Advanced: chaining beats complexity

For anything bigger than one clean deliverable, don't write a monster prompt. Chain:

- **Prompt 1** — Context + outline only
- **Prompt 2** — Flesh out section 1, using outline from Prompt 1
- **Prompt 3** — Flesh out section 2, using the same outline
- **Prompt 4** — Stitch and polish

Each prompt is a KERNEL prompt on its own. The AI carries less load per turn, and errors surface earlier — before they compound.

---

## Anti-patterns to watch for

- **Polite padding.** "Could you please help me try to..." adds nothing. Verbs only.
- **Multiple questions stacked.** "Can you analyze X and also do Y and what about Z?" → split into 3 prompts.
- **Vague quality adjectives.** "Good," "engaging," "professional" — replace with measurable criteria.
- **Assumed context.** Don't assume the AI remembers what you worked on yesterday in a different session. Restate or attach.
- **No escape hatch.** Always include "if you can't do X, say so" for research or factual tasks — prevents hallucinated confidence.

---

## Honest limits

- The metrics in the original post (70% token reduction, 340% accuracy gain, etc.) are self-reported by one anonymous Reddit user. Treat them as vibes, not benchmarks.
- KERNEL is really a mnemonic for standard prompt-engineering hygiene: specificity, scope control, explicit exclusions, verifiable success criteria. The discipline is what matters, not the acronym.
- It won't fix a genuinely ambiguous business question. If you don't know what you want, no framework will tell you.

---

*Use this as a living doc. When a prompt underperforms, add the pattern that failed to the anti-patterns section.*

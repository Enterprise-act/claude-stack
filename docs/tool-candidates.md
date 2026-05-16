# Tool Candidates — MCP / Skill Integration Backlog

Tools spotted in the wild and flagged for evaluation as potential MCP servers or skills in the FSP claude-stack.

---

## Pending Evaluation

### Cursor — Slack-triggered AI coding agent
- **What it does:** Tag `@cursor` in a Slack thread; Cursor investigates issues and opens a PR for review, all in-thread.
- **Fit:** Could replace or complement current manual PR review flows. Relevant if team adopts more Slack-first engineering workflow.
- **Source:** Cursor paid ad (social)
- **Link:** cursor.com

---

### hyperresearch — Automated deep research pipeline
- **What it does:** 16-step pipeline with parallel fetcher agents that searches, collects, and synthesises web data into a persistent, searchable wiki vault. Solves context-rot on long research tasks.
- **Fit:** Strong candidate for a research skill or MCP wrapper. Directly complements `/autoresearch-anything` — could underpin it or replace manual multi-tab research.
- **Repo:** `jordan-gibbs/hyperresearch` (open source)
- **Source:** githubsignals / Hacker News

---

### Supertonic — On-device Text-to-Speech
- **What it does:** 66M parameter TTS model, MIT licensed. Runs on-device (incl. Raspberry Pi), no API keys, no usage fees. 167× faster than real-time on M4 Pro. Supports 5 languages, Chrome extension available.
- **Fit:** Could power audio output for client-facing deliverables, meeting summaries, or accessibility features — at zero marginal cost.
- **Repo:** `supertone-inc/supertonic` (MIT)
- **Source:** LinkedIn / Hicham Taleb

---

### how-to-train-your-gpt — LLM from scratch tutorial
- **What it does:** Chapter-by-chapter walkthrough building a modern LLM from scratch. Covers tokenisation, attention, training loops. Every line commented.
- **Fit:** Staff training / internal upskilling resource rather than a production tool. Good reference for any team member wanting to understand model internals.
- **Repo:** `raiyanyahya/how-to-train-your-gpt`
- **Source:** github.awesome (social)

---

## How to use this file

- Add new candidates with source, fit assessment, and repo/link.
- Move to `INTEGRATED` section below once shipped as a skill or MCP.
- Move to `REJECTED` with a one-line reason if evaluated and declined.

## Integrated

_(none yet)_

## Rejected

_(none yet)_

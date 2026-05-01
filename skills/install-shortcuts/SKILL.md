---
name: install-shortcuts
description: Use when the user asks to install, try, or set up a specific third-party Claude Code toolkit — gstack, ruflo, hyperframes, ai-weekend-builds, or the marketing skills pack. Contains verified one-liner install commands and a brief map of what each toolkit provides so the right one gets picked. Triggers on "install gstack", "set up ruflo", "add hyperframes", "weekend builds", or "marketing skills".
metadata:
  version: 1.0.0
---

# Install Shortcuts — Third-Party Claude Code Toolkits

Each entry: what it is, when to pick it, install command. **Do not install unprompted** — confirm with user first; these are heavyweight and opinionated.

---

## gstack — virtual engineering team (47 skills)

**By:** Garry Tan (YC). MIT. Works with 10 AI coding agents.
**When to pick:** User wants a structured sprint workflow (Think → Plan → Build → Review → Test → Ship → Reflect) with role-based skills: CEO, Designer, Eng Manager, QA, CSO.
**Killer features:**
- `/office-hours` — 6 forcing questions before you code
- `/autoplan` — CEO → design → eng → devex review pipeline
- `/design-shotgun` → `/design-html` — mockup-to-production HTML (30KB, zero deps)
- `/qa` — real Chromium testing, atomic-commit bug fixes, auto regression tests
- `/ship` + `/land-and-deploy` + `/canary` — full deploy chain
- `/cso` — OWASP Top 10 + STRIDE threat modeling
- `/freeze`, `/guard`, `/careful` — safety rails for destructive ops
- `/retro` — weekly retrospective

**Install:**
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
```

**Requirements:** Bun ≥1.0, Node.js (Windows only), Git.

---

## ruflo — multi-agent orchestration (60+ agents)

**By:** ruvnet. 32.9k⭐.
**When to pick:** User wants distributed swarm intelligence with auto-routing across models (cheap → expensive). Better for orchestrated agent fleets than single-workflow tasks.
**Features:** WebAssembly kernel for simple transforms (free), mid-model for mid tasks, Opus for complex decisions. Self-learning memory.

**Install:**
```bash
npx ruflo@latest init --wizard
claude mcp add ruflo -- npx -y ruflo@latest mcp start
npx ruflo daemon start
```

**Spawn a swarm:**
```bash
npx ruflo swarm init --topology hierarchical --max-agents 8 --strategy specialized
```

⚠️ The daemon runs persistently. Per CLAUDE.md lifecycle gate, only start it on LIVE projects.

---

## hyperframes — HTML-native video rendering

**By:** heygen.com. Apache 2.0.
**When to pick:** User wants to generate marketing/product videos from natural-language prompts — MP4 output, deterministic, no React/DSL, no per-render fees.
**Features:** `/hyperframes`, `/hyperframes-cli`, `/gsap` slash commands; GSAP / Lottie / CSS / Three.js animation adapters.

**Install (skills integration):**
```bash
npx skills add heygen-com/hyperframes
```

**Start a project:**
```bash
npx hyperframes init my-video
cd my-video
npx hyperframes preview   # live reload
npx hyperframes render    # MP4 output
```

**Requirements:** Node.js ≥22, FFmpeg.

---

## ai-weekend-builds — 5 starter projects

**By:** kju4q.
**When to pick:** User wants to build a weekend AI project end-to-end. Good for prototyping workflows, not for production.

**Projects (ordered easy → advanced):**
1. **Excalidraw MCP diagram agent** (1–3h) — NL → editable diagram
2. **One-command web researcher** (2–4h) — topic → full report
3. **Personal RAG assistant** (5–8h) — chat with your docs, with memory
4. **Multi-agent research crew** (6–9h) — parallel research + synthesis
5. **Autonomous coding agent** (full day) — reads GitHub issues → writes code

**Install:**
```bash
git clone --depth 1 https://github.com/kju4q/ai-weekend-builds.git ~/Desktop/Claude/Projects/ai-weekend-builds
```

---

## marketing skills pack — 38 growth/marketing skills (ALREADY INSTALLED)

**Status:** Installed 2026-04-23 at `~/.claude/skills/*` (no namespace prefix — names unique).
**By:** coreyhaines31. **What you got:**
Ad creative, AI SEO, ASO audit, A/B testing, churn prevention, cold email, community marketing, competitor alternatives, competitor profiling, content strategy, copy editing, copywriting, customer research, directory submissions, email sequences, form CRO, free tool strategy, launch strategy, lead magnets, marketing ideas, marketing psychology, onboarding CRO, page CRO, paid ads, paywall upgrade CRO, popup CRO, pricing strategy, product marketing context, programmatic SEO, referral program, RevOps, sales enablement, schema markup, SEO audit, signup flow CRO, site architecture, social content.

**Foundation skill:** `product-marketing-context` — seed this first, other skills read it before asking questions.

**Upstream:** https://github.com/coreyhaines31/marketingskills (re-run install for updates).

---

## Companion methodology skills (also installed, same session)

- `meta-ads-m4` — Moonlighters M4 Method (structure → creative → breakdowns → cost caps)
- `ai-self-clean` — slop-cleaner + `/heal` + `/drift` nightly maintenance trio

## Pending / blocked source material

These links required auth or were unfetchable in this session — revisit with a browser when needed:

- UGC ad scripts PDF (Google Drive, `1VWeoqlwMEpMbMBMRsIO0D6_kalk6VSqu`)
- Council AI PDF (Google Drive, `17QEZdgevSeXMiEuBk7qIOIRhzVqkwvmA`)
- Command Center PDF (Google Drive, `1J1t75Iiqdwy1X9ulmTsDdD0mjsQmF2dS`)
- EZ Brain PDF (Google Drive, `16sXZyWIzFBatvu_rfej3oBfXF7ltNcft`)
- Graphy prompt optimizer PDF (Google Drive)
- Growth-exe Claude templates Notion page
- Promptible n8n+Cursor+Claude Notion page
- Designer skills (3-Claude-Code-Skills) Notion page
- Vibe Prospecting landing page (403)
- MEZ lead-gen Notion page
- Tiny Fish Google Doc (500)
- 2 Instagram reels (video — pull via user manually)

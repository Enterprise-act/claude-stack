# Skills catalog

All 191 skills available via `invokeSkill(skillName, message, context)`. Grouped by use case. See `stack/claude-skills.md` for the helper and invocation patterns.

---

## Project management (GSD)

| Skill | Best for |
|-------|----------|
| `gsd-new-project` | Initialize a new project with PROJECT.md |
| `gsd-plan-phase` | Create detailed phase plan (PLAN.md) |
| `gsd-execute-phase` | Execute all plans in a phase with wave-based parallelization |
| `gsd-autonomous` | Run all remaining phases autonomously |
| `gsd-progress` | Check project progress, route to next action |
| `gsd-code-review` | Review source files for bugs, security, quality |
| `gsd-code-review-fix` | Auto-fix issues found in code review |
| `gsd-debug` | Systematic debugging with persistent state |
| `gsd-audit-fix` | Autonomous audit-to-fix pipeline |
| `gsd-audit-milestone` | Audit milestone completion against original intent |
| `gsd-audit-uat` | Cross-phase audit of UAT and verification items |
| `gsd-ship` | Create PR, run review, prepare for merge |
| `gsd-complete-milestone` | Archive completed milestone, prepare next version |
| `gsd-do` | Route freeform text to the right GSD command |
| `gsd-quick` | Execute a trivial task with GSD guarantees |
| `gsd-fast` | Inline task execution — no subagents, no planning overhead |
| `gsd-discuss-phase` | Gather phase context through adaptive questioning |
| `gsd-add-phase` | Add phase to end of current milestone |
| `gsd-insert-phase` | Insert urgent work as decimal phase between existing phases |
| `gsd-remove-phase` | Remove a future phase and renumber subsequent phases |
| `gsd-add-backlog` | Add idea to backlog parking lot |
| `gsd-review-backlog` | Review and promote backlog items to active milestone |
| `gsd-add-todo` | Capture idea or task as todo |
| `gsd-check-todos` | List pending todos and select one to work on |
| `gsd-note` | Zero-friction idea capture |
| `gsd-plant-seed` | Capture forward-looking idea with trigger conditions |
| `gsd-explore` | Socratic ideation and idea routing |
| `gsd-next` | Automatically advance to next logical step |
| `gsd-stats` | Display project statistics |
| `gsd-health` | Diagnose planning directory health |
| `gsd-cleanup` | Archive accumulated phase directories |
| `gsd-docs-update` | Generate or update project documentation |
| `gsd-map-codebase` | Analyze codebase with parallel mapper agents |
| `gsd-scan` | Rapid codebase assessment |
| `gsd-session-report` | Generate session report with token usage and outcomes |
| `gsd-extract_learnings` | Extract decisions, lessons, patterns from completed phase |
| `gsd-milestone-summary` | Comprehensive project summary for team onboarding |
| `gsd-new-milestone` | Start new milestone cycle |
| `gsd-plan-milestone-gaps` | Create phases to close gaps from milestone audit |
| `gsd-analyze-dependencies` | Analyze phase dependencies |
| `gsd-add-tests` | Generate tests for completed phase based on UAT criteria |
| `gsd-ai-integration-phase` | Generate AI design contract for phases involving AI |
| `gsd-ui-phase` | Generate UI design contract for frontend phases |
| `gsd-ui-review` | Retroactive 6-pillar visual audit of frontend code |
| `gsd-secure-phase` | Retroactively verify threat mitigations |
| `gsd-validate-phase` | Audit and fill Nyquist validation gaps |
| `gsd-eval-review` | Audit evaluation coverage of an executed AI phase |
| `gsd-forensics` | Post-mortem for failed GSD workflows |
| `gsd-pr-branch` | Create clean PR branch filtering .planning/ commits |
| `gsd-pause-work` | Create context handoff when pausing mid-phase |
| `gsd-resume-work` | Resume work from previous session with full context |
| `gsd-thread` | Manage persistent context threads for cross-session work |
| `gsd-list-workspaces` | List active GSD workspaces and status |
| `gsd-new-workspace` | Create isolated workspace with independent .planning/ |
| `gsd-remove-workspace` | Remove GSD workspace and clean up worktrees |
| `gsd-workstreams` | Manage parallel workstreams |
| `gsd-manager` | Interactive command center for managing multiple phases |
| `gsd-intel` | Query, inspect, refresh codebase intelligence files |
| `gsd-profile-user` | Generate developer behavioral profile |
| `gsd-import` | Ingest external plans with conflict detection |
| `gsd-set-profile` | Switch model profile for GSD agents |
| `gsd-settings` | Configure GSD workflow toggles |
| `gsd-update` | Update GSD to latest version |
| `gsd-help` | Show available GSD commands |
| `gsd-list-phase-assumptions` | Surface Claude's assumptions about a phase approach |
| `gsd-graphify` | Build, query, inspect project knowledge graph |
| `gsd-join-discord` | Join the GSD Discord community |
| `gsd-reapply-patches` | Reapply local modifications after GSD update |
| `gsd-from-gsd2` | Import a GSD-2 project to GSD v1 format |

---

## SEO & content

| Skill | Best for |
|-------|----------|
| `seo-audit` | Full SEO audit — technical, on-page, off-page |
| `ai-seo` | Optimize content for LLM citations and AI search (AEO/GEO) |
| `programmatic-seo` | Scale SEO pages with templates and data |
| `schema-markup` | Add, fix, or optimize structured data |
| `site-architecture` | Page hierarchy, navigation, URL structure, internal linking |
| `content-strategy` | Plan what content to create and what topics to cover |
| `analytics-tracking` | Set up, improve, or audit analytics measurement |
| `competitor-alternatives` | Competitor comparison and alternative pages for SEO |

---

## Conversion rate optimisation (CRO)

| Skill | Best for |
|-------|----------|
| `ab-test-setup` | Design A/B tests and experimentation programs |
| `page-cro` | Optimize any marketing or landing page for conversions |
| `form-cro` | Optimize lead capture, contact, and application forms |
| `signup-flow-cro` | Optimize signup, registration, trial activation flows |
| `onboarding-cro` | Post-signup onboarding, activation, time-to-value |
| `paywall-upgrade-cro` | In-app paywalls, upgrade screens, feature gates |
| `popup-cro` | Popups, modals, overlays, slide-ins for conversion |
| `churn-prevention` | Cancellation flows, save offers, failed payment recovery |

---

## Marketing & growth

| Skill | Best for |
|-------|----------|
| `marketing-ideas` | Brainstorm marketing strategies and tactics |
| `marketing-plan` | Minimalist content-first marketing plan |
| `marketing-psychology` | Apply behavioral science and psychology principles |
| `meta-ads-m4` | Meta/Facebook/Instagram ad accounts — M4 Method |
| `paid-ads` | Google, Meta, LinkedIn, X ad campaigns |
| `ad-creative` | Generate and iterate ad headlines, descriptions, creative |
| `social-content` | LinkedIn, Twitter/X, Instagram, TikTok content |
| `community-marketing` | Build and leverage communities for product growth |
| `cold-email` | B2B cold outreach emails and follow-up sequences |
| `email-sequence` | Email drip campaigns, nurture sequences, lifecycle flows |
| `lead-magnets` | Lead magnets for email capture |
| `referral-program` | Referral, affiliate, or word-of-mouth programs |
| `directory-submissions` | Submit product to startup/SaaS/AI directories for backlinks |
| `launch-strategy` | Product launch, feature announcement, GTM plan |
| `free-tool-strategy` | Plan and build free tools for lead gen and SEO |

---

## Copywriting & messaging

| Skill | Best for |
|-------|----------|
| `copywriting` | Write or rewrite homepage, landing pages, pricing, about |
| `copy-editing` | Edit, review, or improve existing marketing copy |
| `product-marketing-context` | Create or update product marketing context document |
| `sales-enablement` | Battle cards, pitch decks, one-pagers, objection handling |
| `competitor-profiling` | Research and profile competitors from URLs |

---

## Business strategy

| Skill | Best for |
|-------|----------|
| `validate-idea` | Validate a business idea — minimalist entrepreneur framework |
| `mvp` | Build minimum viable product the minimalist way |
| `processize` | Turn idea into manual-first delivery process |
| `first-customers` | Strategy for selling to first 100 customers |
| `find-community` | Identify communities to build a business around |
| `company-values` | Define company values and culture |
| `marketing-psychology` | Behavioral science applied to business decisions |
| `minimalist-review` | Review any business decision through minimalist lens |
| `grow-sustainably` | Evaluate decisions through sustainable growth lens |
| `pricing-strategy` | Pricing, packaging, monetization strategy |
| `pricing` | Set prices using minimalist entrepreneur principles |
| `revops` | Revenue operations, lead lifecycle, marketing-to-sales handoff |
| `customer-research` | Conduct, analyze, and synthesize customer research |

---

## Video & visual creative

| Skill | Best for |
|-------|----------|
| `seedance-cinematic` | Cinematic film-style video prompts for Seedance/Higgsfield |
| `seedance-social-hook` | Viral hook video prompts for TikTok, Reels, Shorts |
| `seedance-ecommerce-ad` | Product ad video prompts for e-commerce |
| `seedance-brand-story` | Brand storytelling narrative video prompts |
| `seedance-real-estate` | Real estate and architecture showcase video prompts |
| `seedance-fashion-lookbook` | Fashion lookbook and model showcase video prompts |
| `seedance-food-beverage` | Food and beverage video prompts |
| `seedance-music-video` | Music video and beat-synced visual prompts |
| `seedance-anime-action` | Anime and Japanese animation style prompts |
| `seedance-3d-cgi` | 3D CGI and rendered video prompts |
| `seedance-cartoon` | Cartoon and animation style prompts |
| `seedance-motion-design-ad` | Motion design ad prompts for software/tech |
| `seedance-product-360` | 360° product turntable and reveal prompts |
| `seedance-fight-scenes` | Fight scene and action sequence prompts |
| `seedance-comic-to-video` | Convert comic panels / manga to animated video |
| `seedance-auto-generate` | Auto-generate Seedance video on Higgsfield via Playwright |
| `higgsfield-image-auto` | Auto-generate AI image on Higgsfield via Playwright |
| `ugc-hot-girl` | AI image prompt for UGC female ad character |
| `ugc-video-auto` | Full UGC ad pipeline — character image → Seedance video |

---

## Creative production (Koda pipeline)

| Skill | Best for |
|-------|----------|
| `koda-brief` | Turn vague idea into structured creative brief |
| `koda-trends` | Find what's working now in the user's niche |
| `koda-concept` | Brief → 3 distinct creative concepts |
| `koda-script` | Write punchy short-form video scripts |
| `koda-storyboard` | Map every shot with timing, visual descriptions |
| `koda-art-direction` | Define complete visual language for a piece |
| `koda-generate` | Generate AI images and videos from a shot deck |
| `koda-assemble` | Assemble final reel from images, video, voiceover, captions |
| `koda-publish` | Write captions, hashtags, posting strategy |
| `koda-repurpose` | Repurpose a finished reel into multiple formats |

---

## AI & agents

| Skill | Best for |
|-------|----------|
| `multimodal-rag` | Local multimodal knowledge base — Gemini + ChromaDB |
| `programmatic-mcp` | Convert MCP server tools into callable scripts |
| `general-task-agent-orchestration` | Universal agent orchestration for any complex project |
| `agentic-workflow-builder` | Build trigger.dev automations from plain-English descriptions |
| `autoresearch-anything` | Autonomous experimentation pipeline for any business metric |
| `ai-self-clean` | Automated codebase hygiene — dead code, broken branches |
| `council` | Multi-persona deliberation with historical thinkers |
| `skill-optimizer` | Audit and improve skill execution from JSONL transcripts |
| `graphify` | Build knowledge graphs from any input — HTML + JSON output |
| `diagnose` | Disciplined diagnosis loop for hard bugs and regressions |
| `audit-automation` | Audit background automations, cron jobs, daemons, hooks |

---

## Code & engineering

| Skill | Best for |
|-------|----------|
| `improve-codebase-architecture` | Find refactoring and architecture deepening opportunities |
| `grill-with-docs` | Challenge plan against existing domain model |
| `kernel-scope-check` | Scope and clarify ambiguous requests before executing |
| `setup-matt-pocock-skills` | Set up AGENTS.md block for engineering skills |
| `zoom-out` | Get broader context or higher-level perspective |

---

## Knowledge & memory

| Skill | Best for |
|-------|----------|
| `obsidian-cli` | Read, create, search, manage Obsidian vault notes |
| `obsidian-markdown` | Create Obsidian Flavored Markdown with wikilinks |
| `obsidian-bases` | Create Obsidian Bases with views, filters, formulas |
| `vault-query` | Search Claude Development vault, answer with citations |
| `vault-save` | Save insights from conversation into vault |
| `memory-management` | Optimize Claude Code's MEMORY.md auto-management |
| `notebooklm` | Full programmatic access to Google NotebookLM API |
| `dream` | Memory consolidation — scan transcripts, extract patterns |

---

## Utilities

| Skill | Best for |
|-------|----------|
| `defuddle` | Extract clean markdown from web pages, remove nav clutter |
| `json-canvas` | Create and edit JSON Canvas files |
| `fireworks-tech-graph` | Generate technology graph diagrams |
| `brief-to-tasks` | Convert brief into structured task list |
| `install-shortcuts` | Install third-party Claude Code toolkits |
| `programmatic-seo` | SEO pages at scale with templates and data |
| `aso-audit` | App Store / Google Play listing audit |

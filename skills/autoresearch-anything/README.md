# Autoresearch-Anything

A Claude Code skill that applies Andrej Karpathy's autoresearch pattern to ANY business metric with an objectively verifiable success metric. Build an autonomous experimentation pipeline that modifies, measures, keeps or discards, and compounds improvements - all while you sleep.

## Quick Start

```bash
# Clone into your Claude Code skills directory
git clone https://github.com/jamesgoldbach/autoresearch-anything.git ~/.claude/skills/autoresearch-anything

# Invoke the skill in Claude Code
/autoresearch-anything
```

## What It Does

This skill guides you through building a custom autonomous experiment pipeline for any measurable business outcome. Inspired by Karpathy's autoresearch repo (where an AI agent optimizes ML models overnight), this brings the same pattern to cold email reply rates, landing page conversions, ad CTR, newsletter open rates, and anything else you can measure with an API.

The skill handles:
1. **Education** - Explains the autoresearch pattern and how it applies to business
2. **Structured Q&A** - Scopes your specific pipeline (metric, platform, constraints, execution)
3. **Deep Research** - Researches your domain before the first experiment
4. **Scaffold Generation** - Creates a complete project with program.md, config, and connector stubs
5. **Guided Build** - Helps you build the real measurement and deployment connectors
6. **Persistence Setup** - Configures local (launchd + tmux) or cloud (GitHub Actions) execution
7. **Launch** - Gets the autonomous loop running

## How It Works

The core loop follows Karpathy's exact pattern:

```
LOOP FOREVER:
1. Read context (results history, accumulated learnings, knowledge files)
2. Hypothesize (what change might improve the metric?)
3. Modify the experiment file
4. Git commit
5. Deploy
6. Wait (measurement window)
7. Measure (query the metric via API)
8. Keep if improved, discard if not (git reset + redeploy previous)
9. Log learnings (both positive and negative)
10. Repeat
```

The system can never go backwards - every experiment either improves the metric or gets thrown away. Over dozens or hundreds of experiments, small wins compound.

## Requirements

- Claude Code CLI installed
- Git
- `jq` and `tmux` (for local execution: `brew install jq tmux`)
- An API-accessible metric to optimize
- A way to deploy changes programmatically

## What's Inside

```
autoresearch-anything/
├── SKILL.md                     # Master entry point - 8-step setup flow
├── concepts/                    # Educational content
│   ├── autoresearch-principles.md
│   ├── experiment-loop.md
│   └── choosing-your-metric.md
├── qa/                          # Structured Q&A flow
│   ├── qa-flow.md
│   └── idea-seeds.md           # 12 example use cases for inspiration
├── templates/                   # Project scaffold templates
│   ├── program.md.template     # Karpathy-style agent instructions
│   ├── config.json.template
│   ├── CLAUDE.md.template
│   ├── measure.sh.stub         # Measurement connector stub
│   ├── deploy.sh.stub          # Deployment connector stub
│   └── notify.sh.stub          # Notification stub (Telegram/Slack)
├── persistence/                 # Execution setup
│   ├── local-setup.md          # launchd + tmux guide
│   ├── github-actions-setup.md
│   ├── agent-wrapper.sh.template
│   └── autoresearch.yml.template
└── reference/
    └── karpathy-pattern.md     # Distilled patterns from the original repo
```

## Example Use Cases

- **Cold email reply rate** - Optimize email copy, measure via Instantly/Lemlist API
- **Landing page conversion** - Optimize page copy, measure via PostHog/GA4
- **Ad creative CTR** - Optimize ad copy, measure via Facebook/Google Ads API
- **Newsletter open rate** - Optimize subject lines, measure via ConvertKit/Beehiiv
- **Pricing page conversion** - Optimize pricing copy, measure via Stripe + analytics
- **YouTube thumbnail CTR** - Optimize thumbnails, measure via YouTube Data API
- **Chatbot satisfaction** - Optimize system prompt, measure via CSAT score
- **Product descriptions** - Optimize copy, measure via Shopify + analytics

## The Three Knowledge Layers

The system separates foundational knowledge from experimental learnings:

- **user-knowledge.md** - What you know (your docs, best practices, domain expertise). Immutable.
- **research-findings.md** - What the agent discovered during deep research. Immutable.
- **constraints.md** - Hard rules that must never be violated (brand, legal, technical). Immutable.
- **resource.md** - What the agent learns through experimentation. Grows forever with both positive and negative insights.

## Credits

Inspired by [Andrej Karpathy's autoresearch](https://github.com/karpathy/autoresearch) - the original autonomous ML experimentation framework.

## License

MIT

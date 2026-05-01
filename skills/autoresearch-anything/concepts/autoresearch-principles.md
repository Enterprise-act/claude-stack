# Autoresearch Principles

## What Is Autoresearch?

Autoresearch is a pattern created by Andrej Karpathy where an AI agent runs experiments autonomously in a tight loop. The agent modifies something, measures the result against an objective metric, keeps the change if it improved, discards it if it didn't, and repeats - forever. No human in the loop. You wake up to a log of experiments and (hopefully) better results.

The original was designed for machine learning model training. We're applying the exact same pattern to any business metric you can measure with an API.

## Why It Works

The pattern works because of one principle: **guaranteed non-regression with compounding gains.**

Every experiment either improves the metric or gets thrown away. The system can never go backwards. Over dozens or hundreds of experiments, the small wins compound. Karpathy saw an 18% keep rate in his overnight runs - meaning 82% of experiments were discarded. But the 18% that worked stacked on top of each other.

Think of it like evolution: random mutations (experiments) + natural selection (keep/discard based on metric) = improvement over time. It's not intelligent design. It's brute-force experimentation at a pace no human could match.

## The Four Requirements

For autoresearch to work on ANY target, you need exactly four things:

1. **A metric** - A single number that's objectively measurable. Reply rate, conversion rate, CTR, open rate, revenue per visitor. It must be a number, not a feeling.

2. **A thing to change** - The experiment file. Email copy, landing page HTML, ad creative, pricing layout, chatbot prompt. Something the agent can modify between experiments.

3. **A way to measure** - An API or programmatic method to get the current metric value. Your email platform's API, your analytics tool, your ad platform. If you can't query it with a script, you can't automate it.

4. **A way to deploy** - A method to put the new version live. API call to create a campaign, git push to deploy a page, API call to update an ad. The agent needs to be able to ship changes without you.

If any of these four is missing, autoresearch won't work for that target. The Q&A setup will help you verify all four are in place.

## How It Differs from A/B Testing

Traditional A/B testing: run two variants, wait, pick the winner, manually create the next test. Slow, manual, maybe one test per week.

Autoresearch: agent creates a variant, deploys it, measures it, keeps or discards, immediately creates the next variant. Automated, continuous, potentially dozens of experiments per day depending on your measurement window.

The agent also gets smarter over time - it logs what worked and what didn't in resource.md, so each new hypothesis is informed by all previous experiments.

## The Compounding Effect

Each "keep" advances the branch. The next experiment builds on the improved version. Over time:

- Experiment 1: baseline (2.4% reply rate)
- Experiment 5: shorter subject line kept (+0.4%)
- Experiment 12: urgency CTA kept (+0.3%)
- Experiment 23: personalization kept (+0.2%)
- Current best: 3.3% reply rate (+37.5% total improvement)

None of these individual changes are huge. But they compound. And the agent found them by running 23 experiments while you did other things.

For the full technical breakdown of how this maps from Karpathy's ML setup to business applications, see `../reference/karpathy-pattern.md`.

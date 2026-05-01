# Q&A Flow Script

This defines the structured Q&A session that collects all parameters needed to generate the autoresearch pipeline. Use AskUserQuestion for every question. Each group starts with a brief concept explanation.

## Pre-Flight

Before starting questions, briefly explain to the user:
- What we're about to build (an autonomous experiment pipeline)
- That you'll ask questions in 6 groups to scope everything
- That after Q&A, you'll do deep research, generate the scaffold, then build the real connectors together
- Reference `concepts/autoresearch-principles.md` for the full concept overview
- Show `qa/idea-seeds.md` if the user wants inspiration for what to optimize

## Group 1: The Metric

**Explain first:** "The metric is the single most important decision. It must be a single number, measurable via API, with a clear direction (higher or lower = better)."

Reference `concepts/choosing-your-metric.md` for the properties checklist.

**Questions:**

1. **What business outcome do you want to improve?**
   - Options: Cold email performance, Landing page conversion, Ad performance, Newsletter engagement, Other (describe)
   - Header: "Outcome"

2. **What SPECIFIC metric will you track?**
   - Options will vary based on Q1 answer. For cold email: Reply rate, Open rate, Click rate. For landing page: Signup rate, Purchase rate. For ads: CTR, Cost per conversion. Always include "Other" option.
   - Header: "Metric"

3. **Is HIGHER or LOWER better?**
   - Options: Higher is better (conversion rate, reply rate, CTR), Lower is better (bounce rate, cost per acquisition, churn)
   - Header: "Direction"

4. **What is your current baseline value? (if known)**
   - Free text. If unknown, the system will establish it during the first measurement.
   - Header: "Baseline"

**Validation:** Run the properties checklist mentally. If the metric is subjective, composite, or has no clear API access, flag it and suggest alternatives. If disqualified, explain why and suggest a proxy metric.

## Group 2: The Experiment

**Explain first:** "The experiment file is the thing the agent will modify between experiments. The constraints define what must NEVER change."

1. **What will the agent modify between experiments?**
   - Describe what the agent will change. E.g., "The email copy - subject line and body", "The landing page HTML and copy", "The ad headline and description"
   - Free text, no predefined options
   - Header: "Experiment"

2. **What are the hard constraints? What must NEVER change?**
   - Free text. Examples: "Brand colors must stay blue", "Must include legal disclaimer", "Company name must be exact", "Maximum 150 words"
   - Header: "Constraints"

3. **Do you have existing best practices, docs, or knowledge the agent should reference?**
   - Options: Yes (I'll paste/link them), No (use general knowledge + research), Some (I have partial knowledge)
   - If yes: collect the content in a follow-up
   - Header: "Knowledge"

## Group 3: Measurement

**Explain first:** "We need to connect to whatever platform tracks your metric. The measurement window is how long each experiment runs before we judge it."

1. **What platform or tool tracks your metric?**
   - Options: Instantly, Mailchimp, ConvertKit, Beehiiv, PostHog, Google Analytics, Facebook Ads, Google Ads, Stripe, YouTube Analytics, Shopify, Other
   - Header: "Platform"

2. **Does this platform have an API we can query?**
   - Options: Yes, Not sure (I'll check), No (we'll need browser automation)
   - Header: "API access"

3. **How long should each experiment run before measuring?**
   - Options: 4 hours, 12 hours, 24 hours, 48 hours, 7 days, Custom
   - Explain: "This is your measurement window. Shorter = faster iteration but less data. Longer = more reliable but slower."
   - Header: "Window"

4. **What's the minimum data volume needed per experiment?**
   - Free text. Examples: "At least 100 email sends", "At least 200 page visitors", "At least 1000 ad impressions"
   - Header: "Sample size"

**Statistical threshold discussion:** After collecting these answers, discuss with the user what improvement threshold makes sense for their specific volume and metric variance. This is a conversation, not a predefined question. Guide them based on:
- High volume (1000+ data points): even small improvements (>2-5%) are likely real
- Medium volume (100-1000): need larger improvements (>10%) to be confident
- Low volume (<100): need substantial improvements (>20%) or longer measurement windows

Record the agreed threshold.

## Group 4: Deployment

**Explain first:** "The agent needs a way to put changes live. This could be an API call, a git push, or a CLI command."

1. **How do changes get deployed?**
   - Options: API call to platform, Git push (triggers deploy), CLI command, Manual (agent prepares, I deploy), Other
   - Header: "Deploy method"

2. **Can the agent deploy autonomously, or do you want approval first?**
   - Options: Full auto (agent deploys without asking), Approval required (agent prepares and waits), Auto for small changes, approval for big ones
   - Header: "Approval"

## Group 5: Execution

**Explain first:** "Now we set up WHERE and HOW the pipeline runs."

1. **Where should the project directory be created?**
   - Free text. Suggest: ~/Projects/autoresearch-{topic}/
   - Header: "Project path"

2. **How often should the experiment loop run?**
   - This should be >= the measurement window from Group 3
   - Options: Same as measurement window, 2x measurement window, Custom interval
   - Header: "Loop interval"

3. **How do you want to be notified of experiment results?**
   - Options: Telegram bot, Slack webhook, Terminal only (no notifications)
   - Header: "Notifications"

   **If Telegram selected:** Walk through setup inline:
   - "Open Telegram, search for @BotFather"
   - "Send /newbot, choose a name and username"
   - "Copy the bot token"
   - "Send a message to your new bot, then visit https://api.telegram.org/bot<TOKEN>/getUpdates to get your chat_id"
   - Collect BOT_TOKEN and CHAT_ID

   **If Slack selected:** Walk through setup inline:
   - "Go to api.slack.com/apps, create a new app"
   - "Enable Incoming Webhooks, create a webhook for your channel"
   - "Copy the webhook URL"
   - Collect SLACK_WEBHOOK_URL

4. **How should the pipeline run persistently?**
   - Options: Local (launchd + tmux - runs while Mac is on), GitHub Actions (runs in cloud even when laptop is off)
   - Header: "Persistence"

## Group 6: Research Inputs

**Explain first:** "Before the first experiment, the agent will do deep research on your domain. You can also provide your own resources."

1. **Paste any links, documents, or knowledge you want the agent to reference:**
   - Free text. Can be URLs, pasted content, file paths, or "None - just do web research"
   - Header: "Resources"

## Output

After all questions are answered, summarize back to the user:
- Pipeline name (derived from metric + domain)
- Metric: {name} ({direction} = better)
- Experiment file: {description}
- Measurement: {platform}, {window} window, {min_sample} minimum
- Threshold: {agreed threshold}
- Deployment: {method}, {approval setting}
- Execution: {path}, {interval}, {notifications}, {persistence}
- Research: {user resources + web research}

Ask user to confirm before proceeding to deep research and scaffold generation.

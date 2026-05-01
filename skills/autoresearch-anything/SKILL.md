---
name: autoresearch-anything
description: Build an autonomous experimentation pipeline for any business metric using Karpathy's autoresearch pattern. Use when user wants to optimize a metric continuously, set up automated experimentation, or apply autoresearch to their business.
---

# Autoresearch-Anything

This skill guides you through building a custom autonomous experimentation pipeline for ANY business metric. Inspired by Andrej Karpathy's autoresearch - where an AI agent runs experiments in a loop, keeps what works, discards what doesn't, and compounds improvements over time.

You are NOT building a pre-built app. You are guiding the user through scoping, researching, scaffolding, and then building the real infrastructure together.

## How This Works

Follow these 8 steps in order. Each step references specific files in this skill folder for detailed instructions.

---

## Step 1: Introduction and Education

Explain autoresearch to the user. Read `concepts/autoresearch-principles.md` for the full concept overview, then explain in your own words:

- An AI agent runs experiments autonomously in a tight loop
- It modifies something (email copy, landing page, ad creative), measures the result against an objective metric, keeps the change if it improved, discards it if it didn't, and repeats forever
- Over dozens or hundreds of experiments, small wins compound - the system can never go backwards
- The original was designed for ML by Andrej Karpathy. We're applying the exact same pattern to any business metric

Tell the user: "I'll walk you through a structured Q&A to scope your pipeline, then do deep research on your domain, generate a project scaffold, and build the real connectors with you. By the end, you'll have a fully autonomous experiment pipeline."

If the user needs inspiration for what to optimize, read and share `qa/idea-seeds.md`.

---

## Step 2: Structured Q&A

Follow the Q&A flow defined in `qa/qa-flow.md` exactly. Use AskUserQuestion for every question group.

Key points:
- 6 groups of questions covering: metric, experiment, measurement, deployment, execution, research inputs
- Each group starts with a brief concept explanation
- Reference `concepts/choosing-your-metric.md` during Group 1 to validate the metric choice
- Statistical thresholds are discussed and agreed upon during Group 3 (contextual to data volume)
- Notification setup (Telegram/Slack) happens inline during Group 5
- After all questions, summarize everything back to the user for confirmation

Collect all answers as structured data for template rendering in Step 5.

---

## Step 3: Deep Research

After Q&A is confirmed, research the user's specific domain:

1. **Web research**: Use WebSearch to find best practices for the user's specific optimization target. Search for things like:
   - "{metric} optimization best practices"
   - "{platform} API documentation"
   - "how to improve {metric} for {domain}"
   - Proven patterns, common pitfalls, benchmark numbers

2. **User resources**: Read any links, docs, or content the user provided during Q&A Group 6.

3. **Synthesize** findings into two outputs:
   - Content for `research-findings.md` (domain-specific + general optimization principles)
   - Content for `user-knowledge.md` (from what the user provided)

Include general optimization principles in the research findings:
- Test one variable at a time when possible (but agent has freedom to bundle)
- Statistical significance requires sufficient sample size
- Timing matters (day of week, time of day can affect results)
- Diminishing returns - early experiments often yield the biggest gains
- Domain-specific principles discovered during research

---

## Step 4: Create Knowledge Files

Create three immutable knowledge files in the project directory:

1. **`user-knowledge.md`** - Everything the user provided during Q&A (their existing knowledge, docs, best practices, domain expertise). The agent reads this but NEVER modifies it.

2. **`research-findings.md`** - Everything discovered during deep research (web search results, synthesized domain knowledge, general optimization principles). Written once, agent reads but NEVER modifies.

3. **`constraints.md`** - All hard rules from Q&A Group 2 (brand guidelines, legal requirements, technical limits, things that must never change). The agent reads and MUST respect every constraint. Violations make an experiment invalid.

---

## Step 5: Scaffold Generation

Create the project directory at the user-chosen path. Generate all files from templates, substituting Q&A answers for placeholders.

**Files to generate:**

1. `config.json` - from `templates/config.json.template`. Fill all `{{placeholders}}` with Q&A answers.
2. `program.md` - from `templates/program.md.template`. This is the agent's runtime brain. Fill all placeholders.
3. `CLAUDE.md` - from `templates/CLAUDE.md.template`. Bootstrap instructions for the agent.
4. `results.tsv` - from `templates/results.tsv.template`. Header row only.
5. `resource.md` - from `templates/resource.md.template`. Seed with deep research summary stats placeholder.
6. `user-knowledge.md` - from Step 4.
7. `research-findings.md` - from Step 4.
8. `constraints.md` - from Step 4.
9. `experiment/{experiment_file}` - empty stub file for the experiment. Name from Q&A.
10. `connectors/measure.sh` - from `templates/measure.sh.stub`. Copy as-is.
11. `connectors/deploy.sh` - from `templates/deploy.sh.stub`. Copy as-is.
12. `notify.sh` - from `templates/notify.sh.stub`. Copy as-is.
13. `.env.example` - list all required API keys based on Q&A answers.
14. `.env` - copy of .env.example (user will fill in real values).
15. `.gitignore` - ignore .env, logs/, *.log, .crash_count_today.

**After generating files:**
```bash
cd {project_path}
git init
git add -A
git commit -m "autoresearch: initial scaffold for {pipeline_name}"
```

---

## Step 6: Build Phase

This is where you and the user build the real infrastructure together. The stubs must become working scripts.

### 6a: Build measure.sh

"Now let's build your measurement connector. Based on your Q&A, you're using {platform} to track {metric}."

1. Research the platform's API documentation (use WebSearch if needed)
2. Write the real `connectors/measure.sh` that:
   - Connects to the platform's API using credentials from .env
   - Queries the current metric value
   - Outputs in the required format: `metric_value:`, `sample_size:`, `timestamp:`, `experiment_id:`
3. Help the user get their API key and add it to .env
4. Test: `bash connectors/measure.sh` - verify it returns real data

### 6b: Build deploy.sh

"Now let's build your deployment connector."

1. Based on the deployment method from Q&A, write the real `connectors/deploy.sh`
2. Must support `--dry-run` flag
3. Must read the experiment file and deploy it to the platform
4. Test: `bash connectors/deploy.sh --dry-run` - verify it works without deploying

### 6c: Set up notifications

Based on the user's choice from Q&A Group 5:

- **Telegram**: Verify BOT_TOKEN and CHAT_ID are in .env. Test: `bash notify.sh "Test notification from autoresearch"`
- **Slack**: Verify SLACK_WEBHOOK_URL is in .env. Test: `bash notify.sh "Test notification from autoresearch"`
- **Terminal only**: No setup needed. notify.sh will echo to stdout.

### 6d: Create baseline experiment

Using the knowledge files (user-knowledge.md + research-findings.md + constraints.md), create the initial version of the experiment file. This is the baseline that all future experiments will try to beat.

### 6e: Establish baseline measurement

1. Deploy the baseline: `bash connectors/deploy.sh`
2. Wait for data (or measure existing data if available): `bash connectors/measure.sh`
3. Record in results.tsv as the baseline entry
4. Seed resource.md with the deep research findings

---

## Step 7: Persistence Setup

Based on the user's choice from Q&A Group 5:

### If Local (launchd + tmux):

Read `persistence/local-setup.md` for the full step-by-step instructions.

1. Create `scripts/` directory in the project
2. Generate `scripts/agent-wrapper.sh` from `persistence/agent-wrapper.sh.template` - fill in pipeline name and project path
3. Make it executable: `chmod +x scripts/agent-wrapper.sh`
4. Generate the launchd plist at `~/Library/LaunchAgents/com.autoresearch.{pipeline_name}.plist`
   - Detect the PATH for claude: `which claude`
   - Set working directory to project path
   - Set KeepAlive to true, ThrottleInterval to 10
5. Create a convenience start script `scripts/start.sh`:
   ```bash
   #!/bin/bash
   launchctl load ~/Library/LaunchAgents/com.autoresearch.{pipeline_name}.plist
   echo "Pipeline started. Attach: tmux attach -t autoresearch-{pipeline_name}"
   ```
6. Load the service: `launchctl load ~/Library/LaunchAgents/com.autoresearch.{pipeline_name}.plist`
7. Verify: `tmux has-session -t autoresearch-{pipeline_name}`

### If GitHub Actions:

Read `persistence/github-actions-setup.md` for the full step-by-step instructions.

1. Create GitHub repo: `gh repo create {pipeline_name}-autoresearch --private --source=. --push`
2. Add secrets: `gh secret set ANTHROPIC_API_KEY` + platform-specific keys
3. Generate `.github/workflows/autoresearch.yml` from `persistence/autoresearch.yml.template`
4. Convert the loop interval to a cron expression
5. Push: `git add -A && git commit -m "add autoresearch workflow" && git push`
6. Verify: `gh run list --workflow=autoresearch.yml`
7. Trigger test run: `gh workflow run autoresearch.yml`

---

## Step 8: Launch

1. Final git commit with all built infrastructure:
   ```bash
   git add -A
   git commit -m "autoresearch: {pipeline_name} ready to launch"
   ```

2. Confirm the persistence mechanism is running (tmux session active OR GitHub Actions workflow scheduled)

3. Tell the user:
   - "Your pipeline is live."
   - "You'll receive notifications at {channel} after each experiment."
   - "The agent will run its first experiment on the next loop cycle ({interval})."
   - If local: "Attach to watch: `tmux attach -t autoresearch-{pipeline_name}`"
   - If local: "Stop: `launchctl unload ~/Library/LaunchAgents/com.autoresearch.{pipeline_name}.plist`"
   - If GH Actions: "Monitor: `gh run list --workflow=autoresearch.yml`"
   - "View results: `cat results.tsv`"
   - "View learnings: `cat resource.md`"

4. Remind them of the file mutability rules:
   - They can edit: constraints.md, user-knowledge.md, program.md, experiment file
   - The agent manages: resource.md, results.tsv, experiment file
   - Nobody touches: connectors/measure.sh, connectors/deploy.sh (unless rebuilding)

# GitHub Actions Persistence Setup

This sets up your autoresearch pipeline to run in the cloud on a schedule using GitHub Actions. The pipeline runs even when your laptop is off.

## Prerequisites

- GitHub account
- `gh` CLI authenticated (`gh auth login`)
- Anthropic API key

## Step 1: Create a GitHub repository

```bash
cd {{project_path}}
git init
git add -A
git commit -m "initial autoresearch scaffold"

gh repo create {{pipeline_name}}-autoresearch --private --source=. --push
```

## Step 2: Add secrets

Your API keys must be stored as GitHub secrets (never committed to the repo):

```bash
# Required: Anthropic API key for Claude
gh secret set ANTHROPIC_API_KEY

# Add any platform-specific secrets your connectors need:
# gh secret set INSTANTLY_API_KEY
# gh secret set POSTHOG_API_KEY
# etc.
```

## Step 3: Generate the workflow

Copy `autoresearch.yml.template` from the skill's persistence folder:

```bash
mkdir -p {{project_path}}/.github/workflows
cp ~/.claude/skills/autoresearch-anything/persistence/autoresearch.yml.template \
   {{project_path}}/.github/workflows/autoresearch.yml
```

Update the cron expression to match your loop interval. Examples:
- Every 4 hours: `'0 */4 * * *'`
- Every 12 hours: `'0 */12 * * *'`
- Every 24 hours (midnight): `'0 0 * * *'`
- Every 6 hours: `'0 */6 * * *'`

## Step 4: Push and verify

```bash
git add .github/workflows/autoresearch.yml
git commit -m "add autoresearch workflow"
git push

# Verify the workflow is registered
gh run list --workflow=autoresearch.yml

# Manually trigger a test run
gh workflow run autoresearch.yml

# Watch the run
gh run watch
```

## How It Works

Each GitHub Actions run:
1. Checks out your repo (full history for git operations)
2. Installs Claude Code
3. Creates .env from secrets
4. Tells Claude to run ONE experiment cycle
5. Commits results (results.tsv, resource.md, experiment changes) back to the repo

The next scheduled run picks up from the committed state. Context between runs comes entirely from the files in the repo (results.tsv, resource.md, knowledge files).

## Limitations

- **No conversation memory between runs** - each run is a fresh Claude session. All context must come from files.
- **Minimum cron interval is 5 minutes** - but GitHub may delay scheduled runs by minutes to hours during high load.
- **2,000 free minutes/month** on GitHub Actions - each run takes ~5-15 minutes, so budget accordingly.
- **30-minute timeout per run** - if Claude takes longer, the run fails.

## Monitoring

```bash
# View recent runs
gh run list --workflow=autoresearch.yml

# View a specific run's logs
gh run view <run-id> --log

# Check if there are failures
gh run list --workflow=autoresearch.yml --status=failure
```

## Cost Estimate

- **GitHub Actions**: ~5-15 min per run. At 6 runs/day = 30-90 min/day = 900-2700 min/month (within free tier for most usage).
- **Claude API**: Varies by model and context size. Roughly $0.50-2.00 per experiment cycle with Opus.

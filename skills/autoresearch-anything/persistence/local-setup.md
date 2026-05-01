# Local Persistence Setup (launchd + tmux)

This sets up your autoresearch pipeline to run persistently on your Mac using launchd (auto-starts, auto-restarts on crash) and tmux (provides the terminal Claude needs for /loop crons).

## Prerequisites

- `claude` CLI installed and in your PATH
- `tmux` installed (`brew install tmux` if needed)
- `jq` installed (`brew install jq` if needed)

## Step 1: Generate the wrapper script

Copy `agent-wrapper.sh.template` from the skill's persistence folder into your project:

```bash
cp ~/.claude/skills/autoresearch-anything/persistence/agent-wrapper.sh.template {{project_path}}/scripts/agent-wrapper.sh
chmod +x {{project_path}}/scripts/agent-wrapper.sh
```

Update the placeholders in the script (the skill does this automatically during setup).

## Step 2: Generate the launchd plist

Create the file at `~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.autoresearch.{{pipeline_name}}</string>

    <key>ProgramArguments</key>
    <array>
        <string>{{project_path}}/scripts/agent-wrapper.sh</string>
        <string>{{pipeline_name}}</string>
        <string>{{project_path}}</string>
    </array>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>{{project_path}}/logs/stdout.log</string>

    <key>StandardErrorPath</key>
    <string>{{project_path}}/logs/stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>{{detected_path}}</string>
        <key>HOME</key>
        <string>{{home_dir}}</string>
    </dict>

    <key>WorkingDirectory</key>
    <string>{{project_path}}</string>

    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
```

## Step 3: Load the service

```bash
launchctl load ~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist
```

The agent will start immediately.

## Step 4: Verify

```bash
# Check if tmux session is running
tmux has-session -t autoresearch-{{pipeline_name}} && echo "Running" || echo "Not running"

# Attach to watch the agent work
tmux attach -t autoresearch-{{pipeline_name}}

# Detach without stopping: press Ctrl+B then D
```

## Useful Commands

```bash
# Stop the pipeline
launchctl unload ~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist

# Restart (stop then start)
launchctl unload ~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist
launchctl load ~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist

# View logs
tail -f {{project_path}}/logs/stdout.log
tail -f {{project_path}}/logs/stderr.log
cat {{project_path}}/logs/crashes.log

# Check crash count today
cat {{project_path}}/logs/.crash_count_today
```

## Troubleshooting

**Agent not starting:** Check that `claude` is in the PATH defined in the plist. Run `which claude` to find the path.

**Crashes immediately:** Check `logs/stderr.log` for errors. Common issues: missing .env, invalid API key, tmux not installed.

**Rate limited:** The wrapper detects rate limits and applies exponential backoff (5-20 minutes). Check `logs/crashes.log` for RATE_LIMITED entries.

**Exceeded crash limit:** After 3 crashes in one day, the agent halts. Fix the issue, then restart:
```bash
echo "" > {{project_path}}/logs/.crash_count_today
launchctl unload ~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist
launchctl load ~/Library/LaunchAgents/com.autoresearch.{{pipeline_name}}.plist
```

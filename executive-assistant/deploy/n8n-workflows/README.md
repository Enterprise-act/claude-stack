# n8n Workflow Setup for FSP Executive Assistant

## Overview

This n8n workflow handles:
1. Receiving Slack @mentions via webhook
2. Adding an "eyes" reaction to show the bot is processing
3. Calling your AWS-hosted Assistant API
4. Posting the response back to Slack in a thread

## Setup Instructions

### Step 1: Import the Workflow

1. Open your n8n instance: https://enterpriseact.app.n8n.cloud
2. Go to **Workflows** → **Add workflow** → **Import from file**
3. Upload `fsp-executive-assistant.json`

### Step 2: Configure Environment Variables

In n8n, go to **Settings** → **Variables** and add:

| Variable | Value | Description |
|----------|-------|-------------|
| `FSP_ASSISTANT_URL` | `http://YOUR_LIGHTSAIL_IP:8000` | Your AWS server URL |
| `SLACK_BOT_TOKEN` | `xoxb-...` | Slack bot token |

### Step 3: Connect Slack Credentials

1. In the workflow, click on the **"Reply in Slack"** node
2. Click **Create new credential** → **Slack API**
3. Enter your Slack Bot Token (`xoxb-...`)
4. Save and test the connection

### Step 4: Set Up Slack Event Subscription

1. Go to https://api.slack.com/apps → Your App → **Event Subscriptions**
2. Enable Events
3. Set Request URL to your n8n webhook URL:
   ```
   https://enterpriseact.app.n8n.cloud/webhook/fsp-assistant-slack
   ```
4. Under **Subscribe to bot events**, add:
   - `app_mention`
   - `message.im` (for DMs)
5. Save Changes

### Step 5: Activate the Workflow

1. In n8n, toggle the workflow to **Active**
2. Test by @mentioning the bot in Slack

## Workflow Diagram

```
Slack @mention
     │
     ▼
[Webhook receives event]
     │
     ├──► [URL Verification?] ──► [Respond with challenge]
     │
     ├──► [Add 👀 reaction]
     │
     ▼
[Filter: Is valid mention?]
     │
     ▼
[Call AWS Assistant API]
     │
     ├──► Success ──► [Post reply to Slack thread]
     │
     └──► Error ──► [Post error message]
```

## Testing

1. In Slack, type: `@FSP Assistant what's our company mission?`
2. You should see:
   - 👀 reaction appear immediately
   - Response posted in thread within 5-30 seconds

## Troubleshooting

### Webhook not receiving events
- Check Slack Event Subscriptions shows "Verified"
- Ensure workflow is Active in n8n

### API call failing
- Verify `FSP_ASSISTANT_URL` is correct
- Check AWS security group allows port 8000
- Test API directly: `curl http://YOUR_IP:8000/health`

### Slack reply not posting
- Verify Slack credentials are valid
- Check bot has permissions in the channel
- Look at n8n execution logs for errors

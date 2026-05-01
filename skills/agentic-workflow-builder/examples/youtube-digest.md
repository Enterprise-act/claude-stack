# Example: YouTube channel digest

Video reference: [Stop Learning n8n in 2026](https://youtu.be/ZeJXI2MAhj0) — the first demo build.

## What it does

Every 8 hours, check a configured YouTube channel for new videos. For each new video: fetch transcript, generate a structured summary, post to a ClickUp list with the video URL, title, and summary.

## Spec

- **Pattern**: [scheduled-poller](../patterns/scheduled-poller.md)
- **Trigger**: `cron: "0 */8 * * *"`
- **Source**: YouTube channel (env: `YOUTUBE_CHANNEL_ID`)
- **Idempotency key**: `youtube-video:<videoId>`
- **Output**: ClickUp list (env: `CLICKUP_DIGEST_LIST_ID`) — task title = video title, description = summary
- **Max videos per tick**: 20 (fetched from uploads playlist)

## Files

```
src/trigger/youtube-poller.ts      # schedules.task, hands off each new video
src/trigger/summarize-video.ts     # task, fetches transcript + summarizes + posts
src/lib/youtube.ts                 # listChannelUploads, fetchTranscript
src/lib/clickup.ts                 # createTaskInList
```

## Why this shape

The video demo's first pass did this all inside one n8n flow with a schedule trigger, data-table dedupe, transcript scrape, and an AI summarize node — a 6-node graph that took a while to wire up. The trigger.dev version collapses it to two task files because idempotency is handled by the platform, not by a custom dedupe table.

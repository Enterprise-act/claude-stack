# Pattern: Scheduled Poller

**Use when:** "Check [source] every [interval] and if there's something new, [do Y]."

## Shape

```
schedules.task (cron)
  → fetch latest items from source
  → for each item:
      idempotencyKey = natural ID of the item
      await workerTask.trigger(item, { idempotencyKey })
```

The poller does **not** do the work. It discovers new items and hands them to a worker task. This keeps the poll cheap, gives you per-item retries, and makes each item a separately visible run in the dashboard.

## Idempotency is the whole trick

The poller will re-fire on the next tick and see items it's already processed. Without an idempotency key on the worker, you double-process. With a key derived from the item's natural ID (video ID, task ID, email message-id), trigger.dev silently skips duplicate triggers.

Never store "already seen" IDs in your own database unless you have a reason. trigger.dev's idempotency handles it.

## Template

```ts
// src/trigger/youtube-poller.ts
import { schedules, idempotencyKeys, logger } from "@trigger.dev/sdk";
import { summarizeVideo } from "./summarize-video"; // the worker task

export const youtubePoller = schedules.task({
  id: "youtube-channel-poller",
  // every 8 hours
  cron: "0 */8 * * *",
  run: async (payload) => {
    logger.info("Polling channel", { scheduledAt: payload.timestamp });

    const videos = await fetchRecentVideos({
      channelId: process.env.YOUTUBE_CHANNEL_ID!,
      sinceHours: 24, // overlap the window; idempotency will dedupe
    });

    for (const v of videos) {
      const key = await idempotencyKeys.create(`youtube-video:${v.id}`);
      await summarizeVideo.trigger(
        { videoId: v.id, title: v.title, url: v.url },
        { idempotencyKey: key }
      );
    }

    return { scanned: videos.length };
  },
});
```

```ts
// src/trigger/summarize-video.ts
import { task, logger } from "@trigger.dev/sdk";

export const summarizeVideo = task({
  id: "summarize-video",
  retry: { maxAttempts: 3 },
  run: async (payload: { videoId: string; title: string; url: string }) => {
    const transcript = await fetchTranscript(payload.videoId);
    const summary = await llmSummarize(transcript);
    await postToClickUp({ title: payload.title, summary, url: payload.url });
    return { ok: true };
  },
});
```

## Defaults to set every time

- **Cron timezone**: if human-time matters (e.g. "9am daily"), set `cron: { pattern, timezone }` — not a bare string.
- **Overlap the window**: if you poll every 8h, fetch the last ~24h from the source. Idempotency dedupes, so overlap is free insurance against clock skew.
- **maxAttempts on the worker**: 3 is a sane default. Pollers themselves should **not** retry — if a poll fails, wait for the next tick.
- **Log the scan size**: `return { scanned: N }` so you can see at a glance whether the poll is healthy.

## Anti-patterns

- Doing the actual work inside the scheduled task. One slow item blocks the whole tick.
- Storing seen IDs in your own DB. Reinvents trigger.dev's idempotency.
- Tight cron intervals (every minute) for a source that updates hourly. Waste of runs.
- Forgetting that a cron with timezone change (DST) can fire twice or zero times — idempotency saves you.

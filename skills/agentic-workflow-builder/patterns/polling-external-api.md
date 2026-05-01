# Pattern: Polling a Long-Running External API

**Use when:** An external service does async work (image gen, transcription, report build) and exposes a "start job → poll for status" API shape.

Examples: kie.ai's Nano Banana Pro, OpenAI batches, many video/image APIs.

## Shape

```
start job → get job_id
loop:
  status = get_status(job_id)
  if status.done: return status.result
  if attempts >= max: throw TimeoutError
  wait(backoff)
  attempts += 1
```

Trigger.dev's `wait.for` puts the task to sleep without burning compute — use it instead of `setTimeout` for any wait > ~2s.

## Template

```ts
import { task, wait, logger } from "@trigger.dev/sdk";

export const generateImage = task({
  id: "generate-image",
  retry: { maxAttempts: 2 },
  run: async (payload: { prompt: string }) => {
    const { jobId } = await api.createImage({ prompt: payload.prompt });
    logger.info("image job started", { jobId });

    const MAX_ATTEMPTS = 60;   // ~5 min at 5s intervals
    const INTERVAL_SEC = 5;
    for (let n = 1; n <= MAX_ATTEMPTS; n++) {
      const status = await api.getStatus(jobId);
      if (status.done) {
        logger.info("image ready", { jobId, attempts: n });
        return { url: status.url, jobId };
      }
      if (status.error) {
        throw new Error(`image job failed: ${status.error}`);
      }
      await wait.for({ seconds: INTERVAL_SEC });
    }
    throw new Error(`image job ${jobId} timed out after ${MAX_ATTEMPTS} attempts`);
  },
});
```

## Tuning

From the video's demo: the first build polled every 2 seconds and was obviously too aggressive — switched to ~10–20s for image gen. Good starting points:

- **Image generation (Nano Banana Pro, DALL-E, etc.)**: 5s interval, 60 max attempts (~5 min)
- **Transcription (Whisper API, Deepgram)**: 10s interval, 60 max attempts (~10 min)
- **LLM batch jobs**: 60s interval, 60 max attempts (~1 hour)
- **Long reports / scheduled exports**: 5min interval, 24 max attempts (~2 hours)

Always log `{ jobId, attempts }` on every check so the trigger.dev dashboard shows a clean ladder of polls.

## Anti-patterns

- `setTimeout` inside a task. Blocks the worker and racks up compute time. Use `wait.for`.
- No max attempts. The infinity loop is always one API outage away.
- Tight polling intervals (< 2s). You'll hit rate limits before the job finishes.
- Throwing a generic `Error` on timeout. Include the jobId — it's all you have for manual recovery.

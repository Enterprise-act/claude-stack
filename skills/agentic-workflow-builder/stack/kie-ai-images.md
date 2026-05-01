# kie.ai image generation (Nano Banana Pro)

Used in the video's LinkedIn infographic demo. kie.ai exposes an async create → poll-for-status API. Classic shape for [patterns/polling-external-api.md](../patterns/polling-external-api.md).

## Auth

`KIE_AI_API_KEY` from the kie.ai dashboard. Bearer token.

## Wrapper surface

```ts
// src/lib/kie-ai.ts
const BASE = "https://api.kie.ai/api/v1";
const headers = () => ({
  Authorization: `Bearer ${process.env.KIE_AI_API_KEY}`,
  "Content-Type": "application/json",
});

export async function createImage(opts: {
  prompt: string;
  model?: string;   // e.g. "nano-banana-pro"
  aspectRatio?: string;  // "1:1", "16:9", etc.
}) {
  const r = await fetch(`${BASE}/generate`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      model: opts.model ?? "nano-banana-pro",
      prompt: opts.prompt,
      aspect_ratio: opts.aspectRatio ?? "1:1",
    }),
  });
  if (!r.ok) throw new Error(`kie create: ${r.status}`);
  const { task_id } = await r.json();
  return { jobId: task_id as string };
}

export async function getStatus(jobId: string) {
  const r = await fetch(`${BASE}/status/${jobId}`, { headers: headers() });
  if (!r.ok) throw new Error(`kie status: ${r.status}`);
  const data = await r.json();
  return {
    done: data.status === "completed",
    error: data.status === "failed" ? data.error ?? "unknown" : null,
    url: data.result?.url as string | undefined,
  };
}
```

> Note: kie.ai's exact response shape has shifted over time. **Verify against the current kie.ai API docs before shipping** — the names `task_id` / `status` / `result.url` are representative, not contractual.

## Usage with polling

See [patterns/polling-external-api.md](../patterns/polling-external-api.md) for the full pattern. For Nano Banana Pro specifically: **5s interval, 60 max attempts** (~5 min). The video initially polled every 2s and the logs were unreadably dense.

## Prompting

Nano Banana Pro produces infographic-style output well when prompts specify:
- Layout ("four-quadrant stats layout", "hero stat + three supporting points")
- Style ("minimalist, dark background, sans-serif")
- Text content verbatim (numbers and labels to render)

Don't ask it to "summarize" or "research" — generate the text with an LLM first, then pass the finished text into the image prompt.

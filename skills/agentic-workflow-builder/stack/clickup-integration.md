# ClickUp integration

The demo in the video uses ClickUp as the task UI. Keep a thin wrapper in `src/lib/clickup.ts` — every task should call into it, not talk to the API directly.

## Auth

Personal API token (Settings → Apps → API Token): `pk_...`. Store as `CLICKUP_TOKEN`. Base URL: `https://api.clickup.com/api/v2`.

## Minimal wrapper surface

```ts
// src/lib/clickup.ts
const BASE = "https://api.clickup.com/api/v2";
const headers = () => ({
  Authorization: process.env.CLICKUP_TOKEN!,
  "Content-Type": "application/json",
});

export async function listNewTasks(listId: string) {
  // statuses=to%20do filters to unstarted tasks. Poller marks them in_progress
  // immediately to prevent double-pickup.
  const url = `${BASE}/list/${listId}/task?statuses[]=to%20do&include_closed=false`;
  const r = await fetch(url, { headers: headers() });
  if (!r.ok) throw new Error(`clickup list: ${r.status}`);
  const { tasks } = await r.json();
  return tasks.map((t: any) => ({ id: t.id, name: t.name, description: t.text_content }));
}

export async function markInProgress(taskId: string) {
  await fetch(`${BASE}/task/${taskId}`, {
    method: "PUT",
    headers: headers(),
    body: JSON.stringify({ status: "in progress" }),
  });
}

export async function markComplete(taskId: string) {
  await fetch(`${BASE}/task/${taskId}`, {
    method: "PUT",
    headers: headers(),
    body: JSON.stringify({ status: "complete" }),
  });
}

export async function postComment(taskId: string, markdown: string) {
  await fetch(`${BASE}/task/${taskId}/comment`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ comment_text: markdown, notify_all: false }),
  });
}
```

## Status naming

ClickUp lists use per-space status names. Confirm the exact strings ("to do" vs "open", "in progress" vs "in-progress") before hard-coding. The Get List endpoint returns the available statuses.

## Finding the list ID

Easiest path: open the list in ClickUp → URL is `app.clickup.com/<team>/v/l/<list-id>`. Store as `CLICKUP_RESEARCH_LIST_ID` etc. — one env var per watched list.

## Common pitfalls

- **401 "expected ID"** (seen in the demo): the endpoint path used a name instead of a numeric ID. Always use the ID.
- **Custom fields** don't come back unless you pass `custom_fields=true` in the query.
- **Webhook alternative**: ClickUp supports webhooks, but the video's polling approach is simpler to set up and debug. Switch to webhooks only if minute-latency isn't enough.

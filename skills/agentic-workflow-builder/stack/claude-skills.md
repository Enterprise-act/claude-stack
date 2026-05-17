# Claude Skills bridge

Every skill in `carrmjw/claude-stack` can be invoked from a trigger.dev task via the Anthropic API. The skill's `SKILL.md` becomes the system prompt; the task payload becomes the user message. No Claude Code CLI required — pure API.

## Setup

Add to `.env` / trigger.dev Env Vars:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

Install the SDK:

```bash
npm install @anthropic-ai/sdk
```

## The helper — `src/lib/claude-skill.ts`

Copy this into your trigger.dev project. It fetches the skill's `SKILL.md` from the canonical repo at runtime so updates propagate automatically.

```ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic(); // reads ANTHROPIC_API_KEY

const SKILLS_BASE =
  "https://raw.githubusercontent.com/carrmjw/claude-stack/main/skills";

export interface SkillResult {
  content: string;
  inputTokens: number;
  outputTokens: number;
}

/**
 * Invoke any claude-stack skill from a trigger.dev task.
 *
 * @param skillName  Directory name under skills/ — e.g. "seo-audit"
 * @param userMessage  The plain-language request
 * @param context  Optional structured context injected before the message
 *                 (e.g. JSON payload, scraped page content, previous output)
 */
export async function invokeSkill(
  skillName: string,
  userMessage: string,
  context?: string
): Promise<SkillResult> {
  const url = `${SKILLS_BASE}/${skillName}/SKILL.md`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Skill "${skillName}" not found (${res.status}): ${url}`);
  }
  const systemPrompt = await res.text();

  const message = await client.messages.create({
    model: "claude-opus-4-7",
    max_tokens: 8192,
    system: systemPrompt,
    messages: [
      {
        role: "user",
        content: context
          ? `## Context\n\n${context}\n\n## Request\n\n${userMessage}`
          : userMessage,
      },
    ],
  });

  const content = message.content
    .filter((b): b is Anthropic.TextBlock => b.type === "text")
    .map((b) => b.text)
    .join("\n");

  return {
    content,
    inputTokens: message.usage.input_tokens,
    outputTokens: message.usage.output_tokens,
  };
}
```

## Example task — SEO audit on new ClickUp task

```ts
// src/trigger/seo-audit-agent.ts
import { task } from "@trigger.dev/sdk";
import { invokeSkill } from "../lib/claude-skill";
import { markComplete, postComment } from "../lib/clickup";

export const seoAuditAgent = task({
  id: "seo-audit-agent",
  retry: { maxAttempts: 2 },
  run: async (payload: { taskId: string; url: string }) => {
    const result = await invokeSkill(
      "seo-audit",
      `Run a full SEO audit on: ${payload.url}`,
      `ClickUp task ID: ${payload.taskId}`
    );

    await postComment(payload.taskId, result.content);
    await markComplete(payload.taskId);

    return { tokensUsed: result.inputTokens + result.outputTokens };
  },
});
```

## Example task — Content → social posts pipeline

```ts
// src/trigger/social-content-agent.ts
import { task } from "@trigger.dev/sdk";
import { invokeSkill } from "../lib/claude-skill";

export const socialContentAgent = task({
  id: "social-content-agent",
  run: async (payload: { articleUrl: string; articleText: string }) => {
    const result = await invokeSkill(
      "social-content",
      "Generate a LinkedIn post, a Twitter/X thread, and 3 Instagram caption variants.",
      `Article URL: ${payload.articleUrl}\n\nArticle text:\n${payload.articleText}`
    );
    return { posts: result.content };
  },
});
```

## Multi-skill pipeline

Chain skills to build richer automations:

```ts
// Competitor profiling → sales enablement → email sequence
const profile = await invokeSkill(
  "competitor-profiling",
  "Profile this competitor",
  competitorUrl
);

const enablement = await invokeSkill(
  "sales-enablement",
  "Create a battle card based on this competitor profile",
  profile.content
);

const emails = await invokeSkill(
  "cold-email",
  "Write a 3-touch cold email sequence positioning us against this competitor",
  enablement.content
);
```

## CLI-based skills (local machine / server only)

A small number of skills ship executable scripts. These cannot run inside trigger.dev's cloud runtime — they require a machine where the stack is installed (`~/.claude/skills/`). Route these through a self-hosted runner or a separate server endpoint.

| Skill | Script | Command |
|-------|--------|---------|
| `multimodal-rag` | `mmrag.py` | `python3 ~/.claude/skills/multimodal-rag/scripts/mmrag.py ingest <path>` |
| `programmatic-mcp-skill` | `call_tool.py`, `discover_tools.py` | `python3 ~/.claude/skills/programmatic-mcp-skill/scripts/call_tool.py ...` |
| `fireworks-tech-graph` | `generate-diagram.sh` | `bash ~/.claude/skills/fireworks-tech-graph/scripts/generate-diagram.sh` |

## Tips

- **Pass structured context** — JSON payloads, scraped text, previous skill output. The more concrete the context, the better the result.
- **Chain outputs** — each skill returns markdown. Feed it as `context` into the next skill.
- **Pick the tightest skill** — use `seo-audit` not `marketing-ideas` for an SEO task. Narrower system prompts outperform broad ones.
- **Token budget** — `claude-opus-4-7` at 8192 output tokens handles most skills. Drop to `claude-sonnet-4-6` for high-volume steps where quality requirements are lower.
- **Full catalog** — see `stack/skills-catalog.md` for all 191 skills grouped by use case.

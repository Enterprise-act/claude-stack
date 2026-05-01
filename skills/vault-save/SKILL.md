---
name: vault-save
description: Save key insights from the current conversation into the Claude Development Obsidian vault under knowledge/. Creates a dated note with backlinks and tags. Invoke as /vault-save [optional-title].
---

# vault-save

Save conversation insights to the Obsidian vault at `~/Documents/Claude Development`.

## What to do

1. **Identify what's worth saving** — look back at the full conversation. Extract:
   - Decisions made and their rationale
   - Tools, repos, or systems discovered or evaluated
   - Patterns or approaches that worked
   - Any facts the user will want to recall later
   - Skip ephemeral chat — only save durable knowledge

2. **Determine the note title** — use the args if provided, otherwise derive a concise title from the content (e.g. "claude-obsidian-brain-evaluated-2026-04-30")

3. **Write the note** in this format:
```
# <Title>

**Date:** <today's date>
**Tags:** <2-4 relevant tags>

## Summary
<2-3 sentence summary of what this captures>

## Key Insights
- <insight 1>
- <insight 2>
- ...

## Context
<1 paragraph on why this matters / what prompted it>

## Related
- [[<related note if known>]]
```

4. **Create the note** using obsidian CLI:
```bash
obsidian vault="Claude Development" create name="<title>" path="knowledge/<title>.md" content="<formatted content>" silent
```

5. **Confirm** by telling the user: "Saved to [[<title>]] in knowledge/"

## Notes
- Use `\n` for newlines in obsidian CLI content strings
- Always use `silent` flag so the note doesn't steal focus
- If a note with that name already exists, append instead:
  ```bash
  obsidian vault="Claude Development" append file="<title>" content="\n\n---\n\n<new content>"
  ```
- Tags should be lowercase, hyphenated (e.g. `ai-tools`, `claude-code`, `evaluation`)

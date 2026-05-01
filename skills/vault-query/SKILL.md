---
name: vault-query
description: Search the Claude Development Obsidian vault and answer a question with citations. Invoke as /vault-query <question>.
---

# vault-query

Answer questions using content from the Obsidian vault at `~/Documents/Claude Development`.

## What to do

1. **Parse the question** from the args

2. **Search the vault** — run 2-3 searches with different keyword angles:
```bash
obsidian vault="Claude Development" search query="<primary keywords>" limit=8
obsidian vault="Claude Development" search query="<alternate keywords>" limit=5
```

3. **Read the top results** — for each promising file returned, read its content:
```bash
obsidian vault="Claude Development" read file="<note name>"
```
   Focus on notes in `knowledge/`, `ai-tools/`, `sessions/`, `library/`. Skip daily notes unless the question is time-specific.

4. **Synthesize an answer** — write a direct answer to the question, then cite your sources:
   - Inline citations as `[[Note Name]]`
   - End with a **Sources** section listing each note used

5. **Format**:
```
<Direct answer to the question>

<Supporting detail if needed>

**Sources**
- [[Note Name 1]] — <one-line description of what it contributed>
- [[Note Name 2]] — <one-line description>
```

## Notes
- If search returns nothing useful, say so and suggest what to `/vault-save` first
- Prefer specific over general — a note that directly addresses the question beats a tangentially related one
- Do not hallucinate vault content. Only cite notes you actually read
- If the question spans multiple topics, run separate searches per topic and merge

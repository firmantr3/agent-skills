---
name: code-orchestrator
description: >
  Routes user tasks to the right subagent to minimize API calls. Delegates
  codebase exploration to Explore agent and multi-step coding to a code agent.
  Use for any non-trivial task to avoid expensive multi-round main-context work.
invocation: user
---

# Code Orchestrator

Route immediately. Every extra round in main context is an API call that a subagent
could absorb in one shot.

---

## Step 0 — Classify, then Route

Read the task once. Pick the first row that fits.

| Task type | Route |
|-----------|-------|
| "Where is X?", "What does Y do?", "Find files that…" | **→ Explore agent** |
| Edit ≤ 2 files, location already known | **→ Do it directly** |
| Fix / add / refactor across unknown files | **→ Explore → Code agent** |
| New feature, requirements unclear | **→ /plan-kiro → /execute-kiro** |
| "Fix all errors / make all tests pass" | **→ /goal-loop** |
| Code review, analysis, architecture question | **→ Explore agent** |

---

## Rule 1 — Never Explore in Main Context Before Delegating

If you're about to hand off to a code agent anyway, don't read files yourself first.
Either run Explore once and pass its output, or let the code agent explore inline.

```
❌ Bad: main reads 6 files → understands → hands off to code agent (code agent re-reads)
✅ Good: Explore agent finds files + summarizes → code agent gets that summary + task
```

---

## Rule 2 — Pack Subagent Prompts So They Don't Need to Re-Explore

A subagent that re-explores wastes calls. Give it upfront:
- Exact file paths and line ranges (if from Explore results)
- Key symbols, schemas, or interfaces to look at
- Full task + constraints (project uses `bun` not `npm`, `@/` aliases, no `any` types,
  `merchantProfileId` not `merchantId`, let Elysia infer types, etc.)
- What NOT to touch

---

## Rule 3 — Direct Execution Threshold

Stay in main context when:
- File path is already known AND task is ≤ 2 file edits
- Pure shell command with no code understanding needed
- Responding to a subagent escalation

---

## Workflow Templates

### A — Exploration Only
*"Where is X?", "How does Y work?", "Which files handle Z?"*

Spawn **Explore agent**:
```
subagent_type: Explore
search breadth: quick | medium | very thorough  ← pick based on scope
prompt: "Find [X]. Report: file paths, line numbers, key interfaces/functions.
Under 200 words."
```

---

### B — Coding Task (unknown location)
*"Fix X", "Add Y", "Refactor Z"*

**Step 1 — Explore agent** (run first):
```
subagent_type: Explore
prompt: "Find all files relevant to [task]. Report file paths, key functions/types,
data models, and any gotchas. Be thorough but concise."
```

**Step 2 — Code agent** (pass exploration findings inline):
```
subagent_type: claude
prompt: |
  Task: [exact task]

  Relevant files (from prior exploration):
  [paste Explore results here]

  Project constraints:
  - bun/bunx only (never npm/npx)
  - @/ path aliases always
  - No `any` types or @ts-ignore
  - merchantProfileId not merchantId
  - Let Elysia infer handler types — never annotate context manually
  - Zero TS errors: bunx tsc --noEmit after changes
  - Drizzle schema objects only, no raw SQL strings

  Do: [specific changes]
  Do NOT: [out of scope]
```

---

### C — Feature Implementation
Requirements unclear or scope is large → **`/plan-kiro` → `/execute-kiro`**

Don't code without a spec. plan-kiro gates on user approval before execute-kiro runs.

---

### D — Fix-Until-Done Loop
*"Make all tests pass", "Fix all TS errors", "Keep going until CI is green"*

Use **`/goal-loop`**. Give it the verification command and max iterations.

---

## Anti-Patterns

- Reading 5+ files in main context to "understand" before delegating
- Spawning a code agent without passing project conventions
- Running goal-loop for a one-shot fix
- Running two sequential Explore agents when one thorough one covers both
- Delegating a trivial single-file edit (subagent overhead > time saved)

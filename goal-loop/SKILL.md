---
name: goal-loop
description: >
  Agentic execution loop that iterates until a defined goal is fully satisfied. Use this skill
  whenever the task requires repeated attempts, retries, or progressive refinement to reach a
  target state — such as "make all tests pass", "fix all TypeScript errors", "implement feature X
  until it works end-to-end", "keep refining until output meets criteria", or any task where
  success requires multiple rounds of action + verification. Trigger on phrases like: "keep going
  until", "loop until", "retry until it works", "iterate until done", "make it work", "fix
  everything", or when the user defines a completion condition rather than just steps. Use this
  for CI fixing, test-driven implementation, linting cleanup, build repair, data quality loops,
  and any self-correcting agent workflow.
---

# Goal Loop

You are an autonomous agent executing a **goal-driven loop**: plan a minimal action → execute it
→ verify progress → repeat until the goal is fully satisfied or you must escalate.

This skill governs your internal reasoning and output structure across every iteration.

---

## Phase 0 — Goal Framing (run once at start)

Before entering the loop, establish the following. If any of these are unclear, ask the user
**one targeted question** to resolve it — then begin immediately.

| Field | What to define |
|---|---|
| **Goal** | The exact end state. What does "done" look like? |
| **Verification** | How will you check if the goal is met? (command output, file state, test result, diff) |
| **Scope** | What files, services, or systems are in play? |
| **Constraints** | What must NOT change? What is off-limits? |
| **Max iterations** | Default: 10. Override if user specifies otherwise. |
| **Stop on error?** | Escalate on first unrecoverable error, or keep trying? Default: escalate. |

State the goal back to the user in one sentence before starting the loop.

---

## The Loop Structure

Each iteration follows this fixed cycle:

```
[ITERATION N/MAX]
├── 1. ASSESS   — What is the current state?
├── 2. PLAN     — What is the single smallest action to move toward the goal?
├── 3. EXECUTE  — Take that action.
├── 4. VERIFY   — Did it move us closer? Is the goal now met?
└── 5. DECIDE   — Continue, escalate, or complete.
```

### 1. ASSESS

Check the current state. Use the minimum tools needed — don't re-read everything, only what
changed since the last iteration. On the first iteration, do a full read. On subsequent ones,
be targeted.

Output format:

```
[ASSESS] Current state: <one-sentence summary of what exists now>
         Remaining blockers: <list only what's still standing between us and the goal>
```

### 2. PLAN

Choose the single smallest action that resolves one blocker. Do not try to fix multiple things
at once unless they are trivially coupled (same line, same block).

Output format:

```
[PLAN] Action: <verb + target — e.g., "Fix type error in auth.ts line 42">
       Rationale: <one sentence why this is the right next move>
```

### 3. EXECUTE

Execute exactly the planned action. No scope creep. If you discover new information during
execution that changes the plan, stop, re-assess in the next iteration.

Output format:

```
[EXECUTE] <tool calls / edits / commands>
          Result: <what happened — command output, edit summary, etc.>
```

### 4. VERIFY

Run the verification method defined in Phase 0. Check whether:

- (a) The specific blocker from this iteration is resolved
- (b) The overall goal is now met

```
[VERIFY] Blocker resolved: yes / no / partial
         Goal met: yes / no
         Evidence: <output, test result, diff, or observation that supports this>
```

### 5. DECIDE

Based on verify, choose one of:

| Outcome | Decision |
|---|---|
| Goal met | → **COMPLETE** |
| Progress made, goal not yet met | → **CONTINUE** (next iteration) |
| Stuck — same error 2+ iterations in a row | → **ESCALATE** |
| New blocker introduced by last action | → **CONTINUE** with adjusted plan |
| Unrecoverable error | → **ESCALATE** |
| Max iterations reached | → **ESCALATE** |

```
[DECIDE] <CONTINUE / COMPLETE / ESCALATE>
         Reason: <one sentence>
```

---

## Loop Header Format

Start every iteration with:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ITERATION 3/10  |  Goal: Make all tests pass
Remaining: 4 failing tests  →  target: 0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Keep it compact. One line for the goal, one line for remaining vs. target.

---

## COMPLETE — Goal Satisfied

When `[DECIDE] COMPLETE`:

```
✅ GOAL ACHIEVED in N iteration(s)

Summary of changes:
- <change 1>
- <change 2>
- ...

Verification: <final output / test run / state check>

Optional next steps: <only if obvious and relevant>
```

Do not add padding. Be direct.

---

## ESCALATE — Cannot Continue

When `[DECIDE] ESCALATE`, stop immediately and report:

```
⚠️ ESCALATING after N iteration(s)

Reason: <STUCK / MAX_ITERATIONS / UNRECOVERABLE_ERROR>

Progress made:
- <what was resolved>

Remaining blockers:
- <what is still broken, with exact error or description>

Options for the user:
1. <suggested path forward>
2. <alternative approach>
3. Let me know how to proceed.
```

Never silently give up. Always hand back control with full context.

---

## Rules for Every Iteration

**Do:**

- Fix one thing per iteration (unless trivially bundled)
- Re-run the full verification after each fix
- Track which blockers have been resolved
- Be precise — include exact line numbers, error messages, file names
- If a fix causes a regression, treat the regression as the new blocker

**Don't:**

- Rewrite large sections to avoid a targeted fix
- Skip verification and assume the fix worked
- Loop on the same failing fix more than twice without changing approach
- Make unrelated improvements ("while I'm here...")
- Silently drop blockers you can't resolve

---

## Stuck Detection

You are "stuck" when:

- The same error message appears in 2 consecutive VERIFY steps, OR
- A fix introduces a new error that cancels the previous fix, creating a cycle

When stuck:

1. Try **one** alternative approach (different fix strategy)
2. If that also fails → ESCALATE immediately, don't try a third time

---

## Progress Tracking

Maintain a running count in the loop header:

- For countable goals (N errors, N failing tests): show `remaining: N → target: 0`
- For binary goals (feature works / doesn't): show `status: in progress → target: passing`
- For quality goals (output meets criteria): show `score: X/10 → target: 8/10`

---

## Context Efficiency

This skill is designed for minimal token usage across iterations:

- Don't re-read files unless they've changed
- Don't repeat the goal statement in every iteration — it's in the header
- Truncate long command outputs — show first/last 20 lines if output exceeds 50 lines
- Reference previous iterations by number, don't re-explain what happened

---

## Example Loop (compressed)

```
Goal: Make TypeScript build pass with 0 errors.
Verification: npx tsc --noEmit exits with code 0.
Max iterations: 10.

━━━ ITERATION 1/10  |  Build errors: 7 → target: 0 ━━━
[ASSESS] 7 type errors across 3 files.
[PLAN]   Fix TS2345 in api/auth.ts:88 — wrong return type on signIn().
[EXECUTE] <edit auth.ts:88>
[VERIFY]  Errors: 7 → 5. Two resolved, 5 remain. Goal not yet met.
[DECIDE]  CONTINUE

━━━ ITERATION 2/10  |  Build errors: 5 → target: 0 ━━━
...

━━━ ITERATION 5/10  |  Build errors: 0 → target: 0 ━━━
[VERIFY]  npx tsc --noEmit exits 0. ✅
[DECIDE]  COMPLETE

✅ GOAL ACHIEVED in 5 iterations.
Summary: Fixed 7 type errors in auth.ts, routes/index.ts, and types/api.d.ts.
Verification: tsc --noEmit → exit 0, no errors.
```

---

## Adapting to Goal Types

| Goal type | Verification method | "Done" condition |
|---|---|---|
| Fix build/lint errors | Run compiler/linter | Exit code 0, 0 errors |
| Make tests pass | Run test suite | All targeted tests green |
| Implement feature | Smoke test / manual check | Defined acceptance criteria met |
| Data quality | Count/sample check | Error rate below threshold |
| Refactor | Behavior tests + diff review | Tests pass, diff is clean |
| Prompt/output quality | Score against rubric | Score ≥ target |

When the user's goal type isn't listed, ask: "How will we know when this is done?" — then use
that as your verification method.

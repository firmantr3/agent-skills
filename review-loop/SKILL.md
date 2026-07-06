---
name: review-loop
description: >
  Code review loop that runs reviewer subagent, fixes issues on BLOCK, and stops on PASS.
  Use this skill when code needs review-driven iteration: spawn reviewer, apply fixes to resolve
  all issues, and complete when review passes. Triggers on: "review and fix", "review loop", 
  "keep reviewing until pass", or any task combining code review with progressive refinement
  until all issues are resolved.
---

# Review Loop

Autonomous agent executing a **review-driven loop**: run reviewer subagent → assess findings →
fix issues → re-review until code passes. Loop exits on PASS (no issues) or unrecoverable BLOCK.

This skill governs internal reasoning and output structure across every iteration.

---

## Phase 0 — Setup (run once at start)

Establish scope before loop begins. If unclear, ask the user **one targeted question**.

| Field | What to define |
|---|---|
| **Target** | What code/files need review? (path, scope) |
| **Success** | What does PASS look like? (no issues, all comments resolved, specific criteria) |
| **Fix scope** | What can be modified? What is off-limits? |
| **Max iterations** | Default: 5. Override if user specifies otherwise. |

State the target and success criteria back to user in one sentence, then begin.

---

## The Loop Structure

Each iteration follows this fixed cycle:

```
[ITERATION N/MAX]
├── 1. REVIEW   — Spawn reviewer subagent on target code
├── 2. ASSESS   — Parse review output: issues found or PASS?
├── 3. PLAN     — If issues exist, choose smallest fix
├── 4. EXECUTE  — Apply the fix
├── 5. VERIFY   — Did fix address the issue?
└── 6. DECIDE   — Continue, re-review, or complete
```

### 1. REVIEW

Spawn `reviewer` subagent with task: inspect target code, report all issues found or PASS.

Output format:

```
[REVIEW] Spawned reviewer subagent on: <target files/scope>
         Task: <review brief>
```

Wait for reviewer result.

### 2. ASSESS

Parse reviewer output:

- **PASS** = no issues, code meets review criteria
- **BLOCK** = issues found, extract summary of blockers

Output format:

```
[ASSESS] Reviewer returned: <PASS | BLOCK>
         Issues: <list 1–3 top issues if BLOCK, or "none" if PASS>
```

### 3. PLAN

If BLOCK, choose one issue to fix — pick the highest-impact or simplest.

Output format:

```
[PLAN] Issue: <issue type — e.g., "TS error", "logic bug", "missing test">
       Target: <file:line or function name>
       Fix: <brief description of the fix to apply>
```

If PASS, skip to DECIDE.

### 4. EXECUTE

Apply the fix exactly as planned. No scope creep.

Output format:

```
[EXECUTE] <edit / command>
          Result: <what changed>
```

### 5. VERIFY

Check that the fix is sound (type checks, syntax valid, no obvious new issues).

Output format:

```
[VERIFY] Fix applied: yes
         Syntax/types: valid
         Obvious regressions: none
```

### 6. DECIDE

Based on state, choose one of:

| State | Decision |
|---|---|
| Reviewer returned PASS | → **COMPLETE** |
| Issue fixed, need re-review | → **REVIEW** (next iteration) |
| Fix failed or broke code | → **REVERT and ESCALATE** |
| Same issue 2+ iterations | → **ESCALATE** |
| Max iterations reached | → **ESCALATE** |

```
[DECIDE] <REVIEW / COMPLETE / ESCALATE>
         Reason: <one sentence>
```

---

## Loop Header Format

Start every iteration with:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ITERATION 2/5  |  Target: src/auth.ts
Issues: 3 found → target: 0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## PASS — Code Approved

When reviewer returns PASS:

```
✅ CODE REVIEW PASSED in N iteration(s)

Target: <files reviewed>
Issues fixed: <count and summary>

Changes applied:
- <fix 1>
- <fix 2>
- ...

Final state: Ready to merge / use.
```

---

## ESCALATE — Cannot Fix

When unrecoverable:

```
⚠️ ESCALATING after N iteration(s)

Reason: <STUCK / MAX_ITERATIONS / UNRECOVERABLE_ERROR>

Issues fixed so far:
- <resolved issues>

Remaining blockers:
- <issue description with context>

Options:
1. <suggest manual fix or approach>
2. <alternative strategy>
3. Let me know how to proceed.
```

---

## Rules for Every Iteration

**Do:**

- Fix one issue per iteration
- Re-run reviewer after each fix
- Preserve fix intent — don't over-generalize
- Track which issues have been resolved
- Include line numbers and exact error messages

**Don't:**

- Fix multiple unrelated issues at once
- Skip re-review after a fix
- Attempt the same fix 3+ times without escalating
- Refactor unrelated code
- Suppress reviewer feedback

---

## Stuck Detection

Stuck when:

- Reviewer reports the same issue 2 consecutive iterations, OR
- Fix resolves one issue but introduces a new one in same area

When stuck:

1. Try one alternative approach to the issue
2. If that also fails → ESCALATE immediately

---

## Context Efficiency

- Don't re-read code between iterations — reviewer provides current state
- Show reviewer output in full on first iteration, summarized in subsequent
- Reference iteration numbers ("as in iteration 2") don't re-explain
- Truncate large diffs: show first + last 10 lines if >30 lines

---

## Example Loop (compressed)

```
Target: src/api/routes.ts
Success: Reviewer returns PASS (no issues)
Max iterations: 5

━━━ ITERATION 1/5  |  Code review → fix loop ━━━
[REVIEW] Spawned reviewer on src/api/routes.ts
[ASSESS] Reviewer returned BLOCK. Issues: 3 found
         1. Type error: Handler return type
         2. Missing error case
         3. Unused import
[PLAN]   Issue: Type error in handler return (highest priority)
         Fix: Add return type annotation
[EXECUTE] <edit routes.ts line 42>
[VERIFY] Syntax valid, no new errors
[DECIDE] REVIEW (need to re-check all issues)

━━━ ITERATION 2/5  |  Issues: 2 remaining ━━━
[REVIEW] Spawned reviewer on src/api/routes.ts
[ASSESS] Reviewer returned BLOCK. Issues: 2 found
         1. Missing error case
         2. Unused import
[PLAN]   Issue: Missing error case (add try/catch)
[EXECUTE] <edit routes.ts line 48>
[VERIFY] Syntax valid
[DECIDE] REVIEW

━━━ ITERATION 3/5  |  Issues: 1 remaining ━━━
[REVIEW] Spawned reviewer on src/api/routes.ts
[ASSESS] Reviewer returned BLOCK. Issues: 1 found
         1. Unused import
[PLAN]   Issue: Remove unused import
[EXECUTE] <edit routes.ts line 2>
[VERIFY] Syntax valid
[DECIDE] REVIEW

━━━ ITERATION 4/5  |  Final check ━━━
[REVIEW] Spawned reviewer on src/api/routes.ts
[ASSESS] Reviewer returned PASS. No issues.
[DECIDE] COMPLETE

✅ CODE REVIEW PASSED in 4 iterations

Target: src/api/routes.ts
Issues fixed: 3
- Type annotation on handler return
- Error case in try/catch
- Removed unused import

Final state: Ready to merge.
```

---

## When to Escalate Instead of Autofix

Do not use review-loop if:

- Code has architecture issues that need design review (use auditor instead)
- Reviewer recommends refactoring entire module
- Issue is external (missing dependency, config, service)
- Issue requires user decision (which of two approaches)

In these cases, report the blocker and ask the user how to proceed.

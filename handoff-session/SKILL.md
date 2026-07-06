# Handoff Session Skill

**Trigger**: `/handoff`, `handoff session`, `summarize for handoff`, `create handoff`

Captures current session state and creates structured handoff doc for next agent/session to resume work.

## Workflow

1. Reads `CLAUDE.md` for session context (goal, decisions, files touched, branch)
2. Gathers current git branch, modified files, last verification command from history
3. Creates handoff file at `./tasks/handoffs/<YYYY-MM-DD>/<session-title>.md`
4. Populates template with all sections (Goal, State, Decisions, Next steps, Blockers)
5. Outputs file path when done

## Output format

```markdown
## Goal
[one line: what this session is trying to accomplish]

## State
- Branch: [git branch name]
- Files touched: [list of modified files]
- Last passing test / verification command: [command that confirms current state is good]

## Decisions made
- [decision] — [why, briefly]

## Next steps (ordered)
1. [next action]
2. [next action]

## Open questions / blockers
- [blocker or question]
```

## Implementation

Call `skill_ide` with name `handoff-session` when:
- User explicitly requests `handoff` or `summarize for handoff`
- Session ending and work is incomplete (use before closing)
- Handing work to another agent or session

#!/bin/bash
# handoff-session skill: summarize current session to handoff file

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current date
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

# Prompt for session title
echo -e "${BLUE}Session title (for handoff filename):${NC}"
read -r SESSION_TITLE

if [ -z "$SESSION_TITLE" ]; then
  echo "Title required"
  exit 1
fi

# Sanitize filename
SAFE_TITLE=$(echo "$SESSION_TITLE" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')

# Create directory
HANDOFF_DIR="./tasks/handoffs/$DATE"
mkdir -p "$HANDOFF_DIR"

HANDOFF_FILE="$HANDOFF_DIR/$SAFE_TITLE.md"

# Gather info
echo -e "${BLUE}Gathering session info...${NC}"

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
FILES_TOUCHED=$(git status --short 2>/dev/null | awk '{print "  - " $NF}' | head -20)
LAST_CMD=$(history 1 2>/dev/null || echo "unknown")

# Check for CLAUDE.md
GOAL=""
DECISIONS=""
if [ -f "CLAUDE.md" ]; then
  GOAL=$(grep -A1 "^## Goal" CLAUDE.md | tail -1 || echo "")
  DECISIONS=$(grep -A20 "^## Decisions" CLAUDE.md | tail -20 || echo "")
fi

# Prompt for next steps and blockers
echo -e "${BLUE}Next steps (enter each on new line, empty line to finish):${NC}"
NEXT_STEPS=""
while true; do
  read -r step
  [ -z "$step" ] && break
  NEXT_STEPS+="1. $step"$'\n'
done

echo -e "${BLUE}Open questions / blockers (enter each on new line, empty line to finish):${NC}"
BLOCKERS=""
while true; do
  read -r blocker
  [ -z "$blocker" ] && break
  BLOCKERS+="- $blocker"$'\n'
done

# Write handoff file
cat > "$HANDOFF_FILE" << EOF
# Handoff: $SESSION_TITLE
Generated: $DATE at $TIME

## Goal
${GOAL:-[TODO: Add goal]}

## State
- Branch: $BRANCH
- Files touched:
$FILES_TOUCHED
- Last passing test / verification command: [TODO: Add verification command]

## Decisions made
$DECISIONS

## Next steps (ordered)
$NEXT_STEPS

## Open questions / blockers
$BLOCKERS
EOF

echo -e "${GREEN}✓ Handoff created: $HANDOFF_FILE${NC}"
cat "$HANDOFF_FILE"

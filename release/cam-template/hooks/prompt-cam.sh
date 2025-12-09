#!/bin/bash
# Global UserPromptSubmit Hook: Query CAM before Claude processes user message
# This is the "before_user_message" hook from the CAM vision
# Purpose: Provide proactive, intent-based context BEFORE Claude starts processing
# Version: 2.0.0

set -e

# Read hook input from stdin
INPUT=$(cat)

# Parse input fields
USER_PROMPT=$(echo "$INPUT" | jq -r '.prompt // .user_prompt // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6: PRIMER DETECTION (Post-Compact Recovery)
# ═══════════════════════════════════════════════════════════════════════════

PRIMER_DIR="$HOME/.claude/.session-primers"
PRIMER_CONTEXT=""

if [ -d "$CWD" ] && [ "$CWD" != "null" ]; then
  PROJECT_NAME=$(basename "$CWD")
  PRIMER_FILE="$PRIMER_DIR/${PROJECT_NAME}.primer"

  if [ -f "$PRIMER_FILE" ]; then
    # Check primer age (expire after 4 hours)
    # macOS uses -f %m, Linux uses -c %Y
    PRIMER_MTIME=$(stat -f %m "$PRIMER_FILE" 2>/dev/null || stat -c %Y "$PRIMER_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    PRIMER_AGE_SECONDS=$((NOW - PRIMER_MTIME))
    MAX_AGE_SECONDS=$((4 * 60 * 60))  # 4 hours

    if [ "$PRIMER_AGE_SECONDS" -lt "$MAX_AGE_SECONDS" ]; then
      # Read primer
      PRIMER_JSON=$(cat "$PRIMER_FILE")

      # Extract key fields for context injection
      PRIMER_PROJECT=$(echo "$PRIMER_JSON" | jq -r '.project // ""')
      PRIMER_TASK=$(echo "$PRIMER_JSON" | jq -r '.summary.task_context // ""' | head -c 200)
      PRIMER_FILES=$(echo "$PRIMER_JSON" | jq -r '.summary.files_modified | join(", ")' 2>/dev/null | head -c 300 || echo "")
      PRIMER_STATE=$(echo "$PRIMER_JSON" | jq -r '.summary.current_state // ""' | head -c 200)
      PRIMER_PENDING=$(echo "$PRIMER_JSON" | jq -r '.summary.pending_items | join(", ")' 2>/dev/null | head -c 200 || echo "")
      PRIMER_OPS=$(echo "$PRIMER_JSON" | jq -r '.summary.operations | "Edits: \(.edits), Writes: \(.writes), Bash: \(.bash)"' 2>/dev/null || echo "")

      # Build context injection
      PRIMER_CONTEXT="[SESSION PRIMER - Post-Compact Recovery]
Project: ${PRIMER_PROJECT}
Previous task: ${PRIMER_TASK}
Files modified: ${PRIMER_FILES}
Operations: ${PRIMER_OPS}
State: ${PRIMER_STATE}
Pending: ${PRIMER_PENDING:-None}
---"

      # Delete primer (consumed)
      rm -f "$PRIMER_FILE"
    else
      # Primer expired, delete it
      rm -f "$PRIMER_FILE"
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# ORIGINAL LOGIC: Skip checks
# ═══════════════════════════════════════════════════════════════════════════

# Skip if no prompt provided
if [ -z "$USER_PROMPT" ] || [ "$USER_PROMPT" == "null" ]; then
  # Still inject primer if present even without a prompt
  if [ -n "$PRIMER_CONTEXT" ]; then
    jq -n --arg context "$PRIMER_CONTEXT" '{
      continue: true,
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $context
      }
    }'
    exit 0
  fi
  echo '{"continue": true}'
  exit 0
fi

# Skip if CAM not available in this project
if [ ! -d "$CWD/.claude/cam" ]; then
  # Still inject primer even without CAM
  if [ -n "$PRIMER_CONTEXT" ]; then
    jq -n --arg context "$PRIMER_CONTEXT" '{
      continue: true,
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $context
      }
    }'
    exit 0
  fi
  echo '{"continue": true, "hookSpecificOutput": {"cam_status": "not_available", "hookEventName": "UserPromptSubmit"}}'
  exit 0
fi

# Load environment (for GEMINI_API_KEY)
source ~/.claude/hooks/.env 2>/dev/null || true

# Construct semantic query from user's prompt
# Extract key terms - take first 200 chars to avoid overly long queries
QUERY=$(echo "$USER_PROMPT" | head -c 200)

# Query CAM for intent-based context
cd "$CWD"

# Use gtimeout on macOS (brew install coreutils), timeout on Linux
TIMEOUT_CMD=""
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout 5"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout 5"
fi

if [ -n "$TIMEOUT_CMD" ]; then
  CAM_RESULTS=$($TIMEOUT_CMD ./.claude/cam/cam.sh query "$QUERY" 5 2>&1 || echo "No results")
else
  CAM_RESULTS=$(./.claude/cam/cam.sh query "$QUERY" 5 2>&1 || echo "No results")
fi

# Extract top results (more generous than PreToolUse since this is primary context)
TOP_RESULTS=$(echo "$CAM_RESULTS" | head -20)

# ═══════════════════════════════════════════════════════════════════════════
# BUILD OUTPUT WITH PRIMER + CAM (Phase 6)
# ═══════════════════════════════════════════════════════════════════════════

FULL_CONTEXT=""

# Add primer if present (post-compact recovery takes priority)
if [ -n "$PRIMER_CONTEXT" ]; then
  FULL_CONTEXT="${PRIMER_CONTEXT}\n\n"
fi

# Add CAM results
FULL_CONTEXT="${FULL_CONTEXT}CAM PROACTIVE CONTEXT (intent: $(echo "$QUERY" | head -c 80)...)\n\n${TOP_RESULTS}\n\nProject: $(basename "$CWD")\n\n---\nThis context was retrieved BEFORE processing your message based on semantic similarity to your intent."

# Return JSON with proactive context
# This context is injected BEFORE Claude starts processing the message
jq -n \
  --arg context "$FULL_CONTEXT" \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $context
    }
  }'

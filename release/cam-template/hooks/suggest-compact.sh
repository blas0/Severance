#!/bin/bash
# ~/.claude/hooks/suggest-compact.sh
# Stop Hook: Suggest /compact when context grows large
# Version: 2.0.0
#
# Fires: On Stop event (end of assistant turn)
# Purpose: Proactively suggest compaction before auto-compact triggers
#
# CRITICAL: Must check stop_hook_active to prevent infinite loops

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

# Thresholds
WARN_THRESHOLD=800      # Lines before warning
URGENT_THRESHOLD=1200   # Lines before urgent suggestion

# Cooldown: Don't suggest more than once per N minutes
COOLDOWN_MINUTES=15
COOLDOWN_FILE="/tmp/.compact-suggest-cooldown"

# ═══════════════════════════════════════════════════════════════════════════
# INPUT PARSING (Stop Hook Schema)
# ═══════════════════════════════════════════════════════════════════════════

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# ═══════════════════════════════════════════════════════════════════════════
# INFINITE LOOP PREVENTION (Critical!)
# ═══════════════════════════════════════════════════════════════════════════

# If stop_hook_active is true, this is a continuation from a previous stop hook
# Outputting additionalContext would cause another stop, creating an infinite loop
if [ "$STOP_HOOK_ACTIVE" == "true" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Skip if no transcript path
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  echo '{"continue": true}'
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# COOLDOWN CHECK
# ═══════════════════════════════════════════════════════════════════════════

if [ -f "$COOLDOWN_FILE" ]; then
  LAST_SUGGEST=$(cat "$COOLDOWN_FILE")
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_SUGGEST))
  COOLDOWN_SECONDS=$((COOLDOWN_MINUTES * 60))

  if [ "$DIFF" -lt "$COOLDOWN_SECONDS" ]; then
    # Still in cooldown, skip suggestion
    echo '{"continue": true}'
    exit 0
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# TRANSCRIPT SIZE CHECK
# ═══════════════════════════════════════════════════════════════════════════

LINE_COUNT=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')

SUGGESTION=""
if [ "$LINE_COUNT" -gt "$URGENT_THRESHOLD" ]; then
  SUGGESTION="Context is very large (~${LINE_COUNT} lines). Strongly recommend /compact to preserve performance. Session knowledge will be crystallized to CAM."
  # Set cooldown
  date +%s > "$COOLDOWN_FILE"

elif [ "$LINE_COUNT" -gt "$WARN_THRESHOLD" ]; then
  SUGGESTION="Context growing (~${LINE_COUNT} lines). Consider /compact soon to refresh while preserving CAM memory."
  # Set cooldown
  date +%s > "$COOLDOWN_FILE"
fi

# ═══════════════════════════════════════════════════════════════════════════
# OUTPUT
# ═══════════════════════════════════════════════════════════════════════════

# Note: Stop hooks do NOT support hookSpecificOutput.additionalContext
# Only PreToolUse, UserPromptSubmit, PostToolUse support that schema
# Print suggestion to stderr (visible in --verbose mode) instead

if [ -n "$SUGGESTION" ]; then
  echo "[CAM] $SUGGESTION" >&2
fi

# Always return simple continue response for Stop hooks
echo '{"continue": true}'

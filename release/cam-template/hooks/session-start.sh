#!/bin/bash
# Global SessionStart Hook: Validate CAM and load recent context
# Version: 2.0.0

set -e

# Read hook input
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6: SESSION STATE + PRIMER INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

SESSION_STATE_DIR="$HOME/.claude/.session-state"
PRIMER_DIR="$HOME/.claude/.session-primers"

# Ensure directories exist
mkdir -p "$SESSION_STATE_DIR"
mkdir -p "$PRIMER_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# WRITE SESSION STATE (Critical for PreCompact/Stop hooks)
# ─────────────────────────────────────────────────────────────────────────────
# PreCompact and Stop hooks don't receive 'cwd', so we persist it here
if [ -n "$CWD" ] && [ "$CWD" != "null" ] && [ -n "$SESSION_ID" ]; then
  SESSION_STATE_FILE="$SESSION_STATE_DIR/${SESSION_ID}.json"
  PROJECT_NAME_STATE=$(basename "$CWD")
  START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  jq -n \
    --arg cwd "$CWD" \
    --arg project "$PROJECT_NAME_STATE" \
    --arg session_id "$SESSION_ID" \
    --arg start_time "$START_TIME" \
    '{
      cwd: $cwd,
      project: $project,
      session_id: $session_id,
      start_time: $start_time
    }' > "$SESSION_STATE_FILE"

  chmod 600 "$SESSION_STATE_FILE"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CLEAN UP OLD SESSION STATES (older than 24 hours = 1440 minutes)
# ─────────────────────────────────────────────────────────────────────────────
find "$SESSION_STATE_DIR" -name "*.json" -mmin +1440 -delete 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# CLEAN UP EXPIRED PRIMERS (older than 4 hours = 240 minutes)
# ─────────────────────────────────────────────────────────────────────────────
find "$PRIMER_DIR" -name "*.primer" -mmin +240 -delete 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# ORIGINAL LOGIC: Check if CAM exists in this project
# ═══════════════════════════════════════════════════════════════════════════

# Check if CAM exists in this project
if [ ! -d "$CWD/.claude/cam" ]; then
    jq -n --arg cwd "$CWD" '{
      continue: true,
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: ("CAM Status: not_initialized\n\nProject: " + ($cwd | split("/") | .[-1]) + "\nDirectory: " + $cwd + "\n\nCAM not found. To initialize, run:\n  ~/.claude/hooks/init-cam.sh")
      }
    }'
    exit 0
  fi

  # Load environment from GLOBAL location
  source ~/.claude/hooks/.env 2>/dev/null || true

  # Detect timeout command (gtimeout on Mac, timeout on Linux)
  TIMEOUT_CMD=""
  if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout 5"
  elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout 5"
  fi

  # Query CAM for recent context
  cd "$CWD"
  if [ -n "$TIMEOUT_CMD" ]; then
    RECENT_CONTEXT=$($TIMEOUT_CMD ./.claude/cam/cam.sh query "recent session summary" 1 2>&1 | head -20 || echo "No recent context")
    STATS_RAW=$($TIMEOUT_CMD ./.claude/cam/cam.sh stats 2>&1 || echo '')
    # Validate stats is valid JSON, fallback if not
    STATS=$(echo "$STATS_RAW" | jq -c . 2>/dev/null || echo '{"total_embeddings":0,"total_annotations":0}')
  else
    RECENT_CONTEXT=$(./.claude/cam/cam.sh query "recent session summary" 1 2>&1 | head -20 || echo "No recent context")
    STATS_RAW=$(./.claude/cam/cam.sh stats 2>&1 || echo '')
    # Validate stats is valid JSON, fallback if not
    STATS=$(echo "$STATS_RAW" | jq -c . 2>/dev/null || echo '{"total_embeddings":0,"total_annotations":0}')
  fi

  # Extract project name from path
  PROJECT_NAME=$(basename "$CWD")

  # =========================================================================
  # PROACTIVE CAM CONTEXT INJECTION (SessionStart)
  # Query CAM for session patterns (runs once per session)
  # =========================================================================

  SESSION_CONTEXT=""
  if [ -d "$CWD/.claude/cam" ]; then
    cd "$CWD"
    # Query for session patterns (what did we work on recently?)
    # Keep full results (don't truncate with head - get complete context)
    SESSION_CONTEXT=$($TIMEOUT_CMD ./.claude/cam/cam.sh query "session patterns work summary" 2 2>&1 || echo "")

    # Store in temp cache file for other hooks to access
    SESSION_CACHE_FILE="$HOME/.claude/.session-cam-context"
    if [ -n "$SESSION_CONTEXT" ] && [ "$SESSION_CONTEXT" != "No results" ]; then
      echo "$SESSION_CONTEXT" > "$SESSION_CACHE_FILE" 2>/dev/null || true
      chmod 600 "$SESSION_CACHE_FILE" 2>/dev/null || true
    fi
  fi

  # Return status - schema compliant format with session context
  jq -n \
    --arg context "$RECENT_CONTEXT" \
    --argjson stats "$STATS" \
    --arg project "$PROJECT_NAME" \
    --arg cwd "$CWD" \
    --arg session_context "$SESSION_CONTEXT" \
    '{
      continue: true,
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: ("CAM Status: operational\n\nProject: " + $project + "\nDirectory: " + $cwd + "\n\nRecent Context:\n" + $context + "\n\nCAM Stats:\n  Embeddings: " + ($stats.total_embeddings | tostring) + "\n  Annotations: " + ($stats.total_annotations | tostring // "0") + (if $session_context != "" then "\n\nSession Patterns:\n" + $session_context else "" end))
      }
    }'

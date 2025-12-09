#!/bin/bash
# ~/.claude/hooks/crystallize.sh
# PreCompact Hook: Crystallize session knowledge before context compression
# Version: 2.0.0
#
# Fires: Before any compaction (manual /compact or auto-compact)
# Purpose: Preserve session context by summarizing to CAM and primer file
#
# NOTE: PreCompact hooks do NOT receive 'cwd' - must read from session state

set -e

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

SESSION_STATE_DIR="$HOME/.claude/.session-state"
PRIMER_DIR="$HOME/.claude/.session-primers"
PRIMER_EXPIRY_HOURS=4
MAX_TRANSCRIPT_LINES=500
MAX_OPS_LOG_ENTRIES=100

# ═══════════════════════════════════════════════════════════════════════════
# INPUT PARSING (PreCompact Schema)
# ═══════════════════════════════════════════════════════════════════════════

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "unknown"')  # "manual" or "auto"
CUSTOM_INSTRUCTIONS=$(echo "$INPUT" | jq -r '.custom_instructions // ""')

# ═══════════════════════════════════════════════════════════════════════════
# SESSION STATE LOOKUP (Critical: PreCompact doesn't have cwd)
# ═══════════════════════════════════════════════════════════════════════════

SESSION_STATE_FILE="$SESSION_STATE_DIR/${SESSION_ID}.json"
CWD=""

if [ -f "$SESSION_STATE_FILE" ]; then
  CWD=$(jq -r '.cwd // ""' "$SESSION_STATE_FILE")
fi

# Fallback: Try to extract from transcript path structure
# Format: ~/.claude/projects/{hash}/{project-name}/{session}.jsonl
if [ -z "$CWD" ] || [ "$CWD" == "null" ]; then
  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Read first few lines of transcript to find cwd from tool calls
    CWD=$(head -50 "$TRANSCRIPT_PATH" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
  fi
fi

# Validate we have a working directory
if [ -z "$CWD" ] || [ "$CWD" == "null" ] || [ ! -d "$CWD" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Skip if CAM not initialized in this project
if [ ! -d "$CWD/.claude/cam" ]; then
  echo '{"continue": true}'
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: GATHER SESSION INTELLIGENCE
# ═══════════════════════════════════════════════════════════════════════════

cd "$CWD"
PROJECT_NAME=$(basename "$CWD")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Ensure primer directory exists
mkdir -p "$PRIMER_DIR"

# --- 1.1 Operations Log Analysis ---
OPS_LOG="$CWD/.claude/cam/operations.log"
if [ -f "$OPS_LOG" ]; then
  # Get recent operations
  RECENT_OPS=$(tail -n "$MAX_OPS_LOG_ENTRIES" "$OPS_LOG")

  # Count by operation type
  EDIT_COUNT=$(echo "$RECENT_OPS" | grep -c "Edit" || echo "0")
  WRITE_COUNT=$(echo "$RECENT_OPS" | grep -c "Write" || echo "0")
  BASH_COUNT=$(echo "$RECENT_OPS" | grep -c "Bash" || echo "0")
  READ_COUNT=$(echo "$RECENT_OPS" | grep -c "Read" || echo "0")

  # Extract unique files modified
  FILES_MODIFIED=$(echo "$RECENT_OPS" | grep -oE '/[^ ]+\.(py|js|ts|tsx|jsx|sh|md|json|yaml|yml)' | sort -u | head -20)
else
  EDIT_COUNT=0
  WRITE_COUNT=0
  BASH_COUNT=0
  READ_COUNT=0
  FILES_MODIFIED=""
fi

# --- 1.2 Git Context ---
GIT_DIFF_STAT=""
GIT_STATUS=""
UNCOMMITTED_FILES=""

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Get diff stat (changes in recent commits)
  GIT_DIFF_STAT=$(git diff --stat HEAD~5 2>/dev/null | tail -10 || echo "")

  # Get current status
  GIT_STATUS=$(git status --short 2>/dev/null | head -20 || echo "")

  # Count uncommitted changes
  UNCOMMITTED_FILES=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
fi

# --- 1.3 Transcript Sampling (if available) ---
TRANSCRIPT_SAMPLE=""
TRANSCRIPT_LINES=0
USER_INTENTS=""
DECISIONS=""

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TRANSCRIPT_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')

  # Sample last N lines
  TRANSCRIPT_SAMPLE=$(tail -n "$MAX_TRANSCRIPT_LINES" "$TRANSCRIPT_PATH")

  # Extract user messages (heuristic: lines containing "Human:" or user patterns)
  USER_INTENTS=$(echo "$TRANSCRIPT_SAMPLE" | grep -E '"type":"human"' | tail -5 | head -c 500 || echo "")

  # Extract decision patterns (heuristic: "I'll", "Let's", "because", "decision")
  DECISIONS=$(echo "$TRANSCRIPT_SAMPLE" | grep -iE "(I'll|Let's|because|decided|decision|approach)" | tail -5 | head -c 500 || echo "")
fi

# --- 1.4 Todo State (if available) ---
TODO_FILE="/tmp/claude-todos-${SESSION_ID:0:8}.json"
PENDING_TODOS=""
COMPLETED_TODOS=""

if [ -f "$TODO_FILE" ]; then
  PENDING_TODOS=$(jq -r '.[] | select(.status == "pending") | .content' "$TODO_FILE" 2>/dev/null | head -5 || echo "")
  COMPLETED_TODOS=$(jq -r '.[] | select(.status == "completed") | .content' "$TODO_FILE" 2>/dev/null | head -10 || echo "")
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: GENERATE SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

# Build prose summary
PROSE_SUMMARY="SESSION CRYSTALLIZATION
Project: ${PROJECT_NAME}
Session: ${SESSION_ID:0:8}
Timestamp: ${TIMESTAMP}
Trigger: ${TRIGGER}

─── OPERATIONS ───
Edits: ${EDIT_COUNT} | Writes: ${WRITE_COUNT} | Bash: ${BASH_COUNT} | Reads: ${READ_COUNT}

─── FILES MODIFIED ───
${FILES_MODIFIED:-No files tracked}

─── GIT STATE ───
Uncommitted changes: ${UNCOMMITTED_FILES:-0}
${GIT_STATUS:-No git changes}

─── RECENT ACTIVITY ───
${GIT_DIFF_STAT:-No diff available}

─── TASK CONTEXT ───
${USER_INTENTS:-No user intents captured}

─── KEY DECISIONS ───
${DECISIONS:-No decisions captured}

─── COMPLETED ───
${COMPLETED_TODOS:-None tracked}

─── PENDING ───
${PENDING_TODOS:-None tracked}
"

# Build JSON primer
# Ensure all numeric values are valid for jq --argjson
EDIT_COUNT=${EDIT_COUNT:-0}
WRITE_COUNT=${WRITE_COUNT:-0}
BASH_COUNT=${BASH_COUNT:-0}
READ_COUNT=${READ_COUNT:-0}
TRANSCRIPT_LINES=${TRANSCRIPT_LINES:-0}

# Validate they are actually numbers (fallback to 0 if not)
[[ "$EDIT_COUNT" =~ ^[0-9]+$ ]] || EDIT_COUNT=0
[[ "$WRITE_COUNT" =~ ^[0-9]+$ ]] || WRITE_COUNT=0
[[ "$BASH_COUNT" =~ ^[0-9]+$ ]] || BASH_COUNT=0
[[ "$READ_COUNT" =~ ^[0-9]+$ ]] || READ_COUNT=0
[[ "$TRANSCRIPT_LINES" =~ ^[0-9]+$ ]] || TRANSCRIPT_LINES=0

PRIMER_JSON=$(jq -n \
  --arg version "1.0" \
  --arg created_at "$TIMESTAMP" \
  --arg project "$PROJECT_NAME" \
  --arg session_id "$SESSION_ID" \
  --arg trigger "$TRIGGER" \
  --arg task_context "${USER_INTENTS:-Session work}" \
  --arg files_modified "$FILES_MODIFIED" \
  --argjson edits "$EDIT_COUNT" \
  --argjson writes "$WRITE_COUNT" \
  --argjson bash "$BASH_COUNT" \
  --argjson reads "$READ_COUNT" \
  --arg git_changes "${GIT_DIFF_STAT:-None}" \
  --arg current_state "${DECISIONS:-In progress}" \
  --arg pending "${PENDING_TODOS:-None}" \
  --argjson transcript_lines "$TRANSCRIPT_LINES" \
  '{
    version: $version,
    created_at: $created_at,
    project: $project,
    session_id: $session_id,
    trigger: $trigger,
    summary: {
      task_context: $task_context,
      files_modified: ($files_modified | split("\n") | map(select(length > 0))),
      operations: {
        edits: $edits,
        writes: $writes,
        bash: $bash,
        reads: $reads
      },
      git_changes: $git_changes,
      current_state: $current_state,
      pending_items: ($pending | split("\n") | map(select(length > 0)))
    },
    transcript_lines_processed: $transcript_lines
  }')

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: PERSIST TO CAM
# ═══════════════════════════════════════════════════════════════════════════

# Store summary to CAM with primer tags
CAM_OUTPUT=$(./.claude/cam/cam.sh note \
  "Session Primer: ${PROJECT_NAME} (${SESSION_ID:0:8})" \
  "$PROSE_SUMMARY" \
  "session-primer,pre-compact,${PROJECT_NAME},${SESSION_ID:0:8},continuity" \
  2>/dev/null || echo "")

# Extract embedding ID from output
CAM_EMBEDDING_ID=$(echo "$CAM_OUTPUT" | grep -oE 'ID: [a-f0-9]+' | head -1 | cut -d' ' -f2 || echo "")

# Add embedding ID to primer JSON
if [ -n "$CAM_EMBEDDING_ID" ]; then
  PRIMER_JSON=$(echo "$PRIMER_JSON" | jq --arg id "$CAM_EMBEDDING_ID" '. + {cam_embedding_id: $id}')
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: WRITE PRIMER FILE
# ═══════════════════════════════════════════════════════════════════════════

PRIMER_FILE="$PRIMER_DIR/${PROJECT_NAME}.primer"
echo "$PRIMER_JSON" > "$PRIMER_FILE"
chmod 600 "$PRIMER_FILE"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: OUTPUT
# ═══════════════════════════════════════════════════════════════════════════

# Return success with acknowledgment
jq -n \
  --arg context "Session crystallized to CAM (ID: ${CAM_EMBEDDING_ID:-none}). Primer cached for post-compact recovery." \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "PreCompact",
      additionalContext: $context
    }
  }'

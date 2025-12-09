#!/usr/bin/env bash
# cam-note.sh - Store ephemeral notes in CAM without creating files
# Version: 2.0.0
# Usage: cam-note.sh "Title" "Content" ["tag1,tag2,tag3"]

set -euo pipefail

# Input validation
TITLE="${1:?Error: Title required}"
CONTENT="${2:?Error: Content required}"
TAGS="${3:-ephemeral,session-note}"

# Detect project directory
# First check current directory, then check if CWD was passed via environment
if [[ -d "./.claude/cam" ]]; then
    CAM_DIR="./.claude/cam"
elif [[ -n "${CAM_PROJECT_DIR:-}" ]] && [[ -d "${CAM_PROJECT_DIR}/.claude/cam" ]]; then
    CAM_DIR="${CAM_PROJECT_DIR}/.claude/cam"
else
    echo "Error: CAM directory not found. Run from a CAM-initialized project." >&2
    exit 1
fi

# Guard: Skip annotation during upgrade (race condition mitigation)
# The .backup directory only exists during upgrade, preventing circular dependency
# where PostToolUse hook tries to annotate cam.sh while it's being replaced
if [[ -f "${CAM_DIR}/.backup/cam.sh" ]]; then
    echo '{"continue": true}' | jq . >/dev/null 2>&1 || echo '{"continue": true}'
    exit 0
fi

# Generate unique ID (title + timestamp hash) - portable for Mac/Linux
NOTE_ID=$(echo -n "${TITLE}-$(date +%s)" | md5 2>/dev/null || echo -n "${TITLE}-$(date +%s)" | md5sum | cut -d' ' -f1)

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Prepare metadata JSON - properly escape all fields for shell/Python JSON parsing
METADATA=$(jq -n \
  --arg type "ephemeral_note" \
  --arg title "$TITLE" \
  --arg created "$TIMESTAMP" \
  --arg session_id "${SESSION_ID:-unknown}" \
  --arg project "$(basename "$(pwd)")" \
  '{
    type: $type,
    title: $title,
    created: $created,
    session_id: $session_id,
    project: $project
  }')

# Escape CONTENT for safe JSON passing
CONTENT_ESCAPED=$(echo "$CONTENT" | jq -Rs .)

# Store in CAM using annotate - capture the actual embedding ID from output
ANNOTATE_OUTPUT=$("${CAM_DIR}/cam.sh" annotate "$CONTENT_ESCAPED" \
  --id "${NOTE_ID}" \
  --tags "${TAGS}" \
  --metadata "$METADATA" 2>&1 | grep -v "^Warning:" || true)

# Extract the embedding ID from "[v] Annotation stored: <id>" output
ACTUAL_EMB_ID=$(echo "$ANNOTATE_OUTPUT" | grep -o 'Annotation stored: [a-f0-9]*' | cut -d' ' -f3 || echo "")

# Output with actual embedding ID for relationship tracking (v1.4.0)
if [ -n "$ACTUAL_EMB_ID" ]; then
  echo "[v] Stored ephemeral note: ${TITLE} (ID: ${ACTUAL_EMB_ID})"
else
  echo "[v] Stored ephemeral note: ${TITLE} (ID: ${NOTE_ID:0:16}...)"
fi

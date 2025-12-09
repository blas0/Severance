#!/bin/bash
# Global PostToolUse Hook: Annotate operations to CAM
# Version: 2.0.0

set -e

# Read hook input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
SUCCESS=$(echo "$INPUT" | jq -r '.tool_response.success // true')
CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Skip if CAM not available in this project
if [ ! -d "$CWD/.claude/cam" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Annotate all code modifications (Edit, Write, Bash, Read)
# Don't filter for "significance" - let the system learn what matters
ANNOTATED_OPS=("Edit" "Write" "Bash" "Read")
if [[ ! " ${ANNOTATED_OPS[@]} " =~ " ${TOOL_NAME} " ]]; then
  echo '{"continue": true}'
  exit 0
fi

# Create annotation summary
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PROJECT_NAME=$(basename "$CWD")

# Extract operation details
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .command // "unknown"' | head -c 100)
SUMMARY="${TOOL_NAME} operation on ${FILE_PATH} (success: ${SUCCESS})"

# Store in operations log (keep for backward compat)
echo "[$TIMESTAMP] [${PROJECT_NAME}] $SUMMARY" >> "$CWD/.claude/cam/operations.log"

# Store in CAM as embedding via cam-note.sh and capture ID
cd "$CWD"
CONTENT="Operation: ${TOOL_NAME}
Project: ${PROJECT_NAME}
Target: ${FILE_PATH}
Success: ${SUCCESS}
Session: ${SESSION_ID:0:8}
Timestamp: ${TIMESTAMP}"

# Run annotation synchronously to capture embedding ID for relationship creation
NOTE_OUTPUT=$(~/.claude/hooks/cam-note.sh \
  "Op: ${TOOL_NAME} ${FILE_PATH##*/}" \
  "$CONTENT" \
  "operation,${TOOL_NAME},auto-annotated,session-${SESSION_ID:0:8}" \
  2>/dev/null || echo "")

# Extract operation embedding ID from note output (format: "ID: abc123...")
OP_EMBEDDING_ID=$(echo "$NOTE_OUTPUT" | grep -o 'ID: [a-f0-9]*' | head -1 | cut -d' ' -f2 || echo "")

# =========================================================================
# PHASE 3: Automatic Relationship Creation (v1.4.0)
# Create "modifies" relationships when editing .ai/ documentation files
# =========================================================================
RELATIONSHIP_CREATED=""
if [[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]] && [[ "$FILE_PATH" =~ \.ai/ ]] && [[ -n "$OP_EMBEDDING_ID" ]]; then
  # Try to find the document embedding for the target file
  DOC_EMBEDDING_ID=$(./.claude/cam/cam.sh find-doc "$FILE_PATH" 2>/dev/null || echo "")

  if [ -n "$DOC_EMBEDDING_ID" ]; then
    # Create "modifies" relationship: operation -> document
    ./.claude/cam/cam.sh relate "$OP_EMBEDDING_ID" "$DOC_EMBEDDING_ID" "modifies" 0.9 2>/dev/null || true
    RELATIONSHIP_CREATED="[^] Relationship: ${OP_EMBEDDING_ID:0:8} --modifies--> ${DOC_EMBEDDING_ID:0:8}"
  fi
fi

# =========================================================================
# PHASE 5: Automatic File Ingestion (v1.5.0)
# Auto-ingest modified files to keep CAM in sync with codebase
# =========================================================================
AUTO_INGEST_MSG=""
if [[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]] && [[ "$SUCCESS" == "true" ]] && [[ -f "$FILE_PATH" ]]; then
  # Check file extension to determine if it's ingestible
  EXT="${FILE_PATH##*.}"
  SHOULD_INGEST=false

  # Code files
  if [[ "$EXT" =~ ^(py|js|ts|tsx|jsx|go|rs|java|c|cpp|h|rb|php|swift|kt|scala|sh|bash|zsh)$ ]]; then
    SHOULD_INGEST=true
  fi

  # Doc files
  if [[ "$EXT" =~ ^(md|mdx|rst|txt)$ ]]; then
    SHOULD_INGEST=true
  fi

  # Config files
  if [[ "$EXT" =~ ^(json|yaml|yml|toml|ini|cfg|conf)$ ]]; then
    SHOULD_INGEST=true
  fi

  # Skip large files (>100KB), lock files, and ignored paths
  if [[ "$SHOULD_INGEST" == "true" ]]; then
    FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo "0")

    # Skip if too large
    if [[ "$FILE_SIZE" -gt 102400 ]]; then
      SHOULD_INGEST=false
    fi

    # Skip lock files and node_modules
    if [[ "$FILE_PATH" =~ (package-lock|yarn\.lock|pnpm-lock|node_modules|__pycache__|\.git/) ]]; then
      SHOULD_INGEST=false
    fi
  fi

  # Perform smart ingest (only if file changed)
  if [[ "$SHOULD_INGEST" == "true" ]]; then
    INGEST_OUTPUT=$(./.claude/cam/cam.sh ingest "$FILE_PATH" 2>&1 || echo "")

    if echo "$INGEST_OUTPUT" | grep -q "\[v\] Ingested"; then
      # Extract embedding ID from output
      INGEST_ID=$(echo "$INGEST_OUTPUT" | grep -o '-> [a-f0-9]*' | head -1 | cut -d' ' -f2 || echo "")
      AUTO_INGEST_MSG="[+] Auto-ingested: ${FILE_PATH##*/} -> ${INGEST_ID:0:8}"
    elif echo "$INGEST_OUTPUT" | grep -q "unchanged"; then
      # File unchanged, no need to re-ingest
      :
    fi
  fi
fi

# Check if this is a CAM infrastructure file modification
CAM_INFRA_REMINDER=""
if [[ "$FILE_PATH" =~ cam_core\.py ]] || \
   [[ "$FILE_PATH" =~ cam\.sh ]] || \
   [[ "$FILE_PATH" =~ \.claude/hooks/ ]] || \
   [[ "$FILE_PATH" =~ cam-template/ ]] || \
   [[ "$FILE_PATH" =~ CLAUDE\.md ]]; then
  CAM_INFRA_REMINDER="[!] CAM INFRASTRUCTURE MODIFIED: Remember to run './cam.sh release <version>' to bump version and update CHANGELOG.md"
fi

# Return acknowledgment - schema compliant format
CONTEXT_MSG="$SUMMARY\n\nProject: $PROJECT_NAME"
if [ -n "$RELATIONSHIP_CREATED" ]; then
  CONTEXT_MSG="$CONTEXT_MSG\n\n$RELATIONSHIP_CREATED"
fi
if [ -n "$AUTO_INGEST_MSG" ]; then
  CONTEXT_MSG="$CONTEXT_MSG\n\n$AUTO_INGEST_MSG"
fi
if [ -n "$CAM_INFRA_REMINDER" ]; then
  CONTEXT_MSG="$CONTEXT_MSG\n\n$CAM_INFRA_REMINDER"
else
  CONTEXT_MSG="$CONTEXT_MSG\n\n[v] CAM updated and embedded"
fi

jq -n \
  --arg context "$CONTEXT_MSG" \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $context
    }
  }'

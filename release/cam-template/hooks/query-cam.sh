#!/bin/bash
# Global PreToolUse Hook: Smart decision-point CAM queries with caching
# Version: 2.0.0

set -e

  # Read hook input
  INPUT=$(cat)
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
  TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input | tostring')
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
  CWD=$(echo "$INPUT" | jq -r '.cwd')

  # Skip if CAM not available in this project
  if [ ! -d "$CWD/.claude/cam" ]; then
    echo '{"continue": true, "hookSpecificOutput": {"cam_status": "not_available"}}'
    exit 0
  fi

  # Load environment from GLOBAL location
  source ~/.claude/hooks/.env 2>/dev/null || true

  # =========================================================================
  # SMART DECISION-POINT FILTERING
  # Only query CAM at high-value decision points (avoid bloat)
  # =========================================================================

  SHOULD_QUERY=false
  QUERY_TYPE="standard"

  case "$TOOL_NAME" in
    Edit|Write)
      # Code/file modifications are high-value decisions
      SHOULD_QUERY=true
      QUERY_TYPE="code_pattern"
      ;;
    Bash)
      # Only query for architectural/complex Bash operations
      if echo "$PROMPT" | grep -iE "(migrate|refactor|architecture|deploy|setup|infrastructure|pattern)"; then
        SHOULD_QUERY=true
        QUERY_TYPE="operation_pattern"
      fi
      ;;
    Read|Glob|Grep)
      # Information gathering, not decision-making
      SHOULD_QUERY=false
      ;;
    *)
      SHOULD_QUERY=false
      ;;
  esac

  # If query not needed, return empty context (no bloat)
  if [ "$SHOULD_QUERY" = false ]; then
    jq -n \
      '{
        continue: true,
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow"
        }
      }'
    exit 0
  fi

  # =========================================================================
  # CACHING LAYER
  # Avoid re-querying same patterns within 30 minutes
  # =========================================================================

  CACHE_DIR="$HOME/.claude/.cam-cache"
  mkdir -p "$CACHE_DIR"

  # Extract file name if reading/editing a file
  FILE_TARGET=""
  if echo "$TOOL_INPUT" | jq -e '.file_path' >/dev/null 2>&1; then
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path')
    FILE_TARGET=$(basename "$FILE_PATH" 2>/dev/null || echo "")
  fi

  # Construct semantic query
  if [ -n "$FILE_TARGET" ]; then
    QUERY="$PROMPT $FILE_TARGET $TOOL_NAME"
  else
    QUERY="$PROMPT $TOOL_NAME"
  fi

  # Create cache key (hash of query type + query content)
  CACHE_KEY=$(echo -n "$QUERY_TYPE:$QUERY" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "no-md5")
  CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

  # Check if cache exists and is fresh (within 30 minutes)
  CAM_RESULTS=""
  if [ -f "$CACHE_FILE" ]; then
    FILE_AGE=$(($(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [ "$FILE_AGE" -lt 1800 ]; then
      # Cache hit - use cached result
      CAM_RESULTS=$(cat "$CACHE_FILE")
      FROM_CACHE=true
    fi
  fi

  # If not cached, query CAM
  if [ -z "$CAM_RESULTS" ]; then
    cd "$CWD"
    # Use gtimeout on macOS, timeout on Linux, or no timeout if neither exists
    TIMEOUT_CMD=""
    if command -v gtimeout >/dev/null 2>&1; then
      TIMEOUT_CMD="gtimeout 2"
    elif command -v timeout >/dev/null 2>&1; then
      TIMEOUT_CMD="timeout 2"
    fi

    if [ -n "$TIMEOUT_CMD" ]; then
      CAM_RESULTS=$($TIMEOUT_CMD ./.claude/cam/cam.sh query "$QUERY" 3 2>&1 || echo "No results")
    else
      CAM_RESULTS=$(./.claude/cam/cam.sh query "$QUERY" 3 2>&1 || echo "No results")
    fi

    # Store in cache for future use
    if [ "$CAM_RESULTS" != "No results" ]; then
      echo "$CAM_RESULTS" > "$CACHE_FILE" 2>/dev/null || true
    fi
  fi

  # Extract the first complete result (not just 3 lines)
  # CAM results are numbered: "1. [Score: X] ID\n   content..."
  # Extract everything up to the next numbered result or EOF
  FIRST_RESULT=$(echo "$CAM_RESULTS" | awk '/^1\. \[Score:/{p=1} p && /^[0-9]+\. \[Score:/{if(NR>1) exit} p' || echo "")

  # Phase 1 Workaround: Auto-annotate CAM queries (until PostCAMQuery hook available)
  # Only annotate if results are not empty and query looks intentional (contains user intent)
  if [ "$FIRST_RESULT" != "No results" ] && [ -n "$PROMPT" ]; then
    # Annotation happens asynchronously in background (non-blocking)
    (
      # Create annotation summary
      RESULT_COUNT=$(echo "$CAM_RESULTS" | wc -l)
      ANNOTATION_CONTENT="CAM Query Auto-Annotated

Query: ${QUERY}
Results Found: ${RESULT_COUNT} lines

Results Summary:
$(echo "$FIRST_RESULT" | head -5)"

      # Store in CAM using cam-note.sh (background, non-blocking)
      if [ -x ~/.claude/hooks/cam-note.sh ]; then
        cd "$CWD"
        SESSION_ID="${SESSION_ID:-unknown}" ~/.claude/hooks/cam-note.sh \
          "Query: ${QUERY}" \
          "$ANNOTATION_CONTENT" \
          "cam-query,auto-annotated" >/dev/null 2>&1 || true
      fi
    ) &
  fi

  # Return minimal JSON (avoid context bloat)
  # Only include context if results found
  if [ "$FIRST_RESULT" != "No results" ] && [ -n "$FIRST_RESULT" ]; then
    jq -n \
      --arg context "$FIRST_RESULT" \
      '{
        continue: true,
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          additionalContext: ("CAM Patterns:\n" + $context)
        }
      }'
  else
    jq -n \
      '{
        continue: true,
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow"
        }
      }'
  fi

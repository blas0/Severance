#!/bin/bash
# Global PostCAMQuery Hook: Annotate CAM semantic queries
# Version: 2.0.0
# Status: DORMANT (Future Implementation)
#
# This hook will annotate CAM semantic query operations once the
# PostCAMQuery hook system is integrated into Claude Code.
# Currently (Phase 1), CAM queries are annotated manually via cam-note.sh.
#
# When activated, this hook will be called with:
# {
#   "session_id": "abc123",
#   "hook_event_name": "PostCAMQuery",
#   "query": "user's semantic query",
#   "results_count": 6,
#   "result_summary": "summary of results",
#   "cwd": "/path/to/project"
# }
#
# And should return:
# {
#   "continue": true,
#   "hookSpecificOutput": {
#     "query_annotated": true,
#     "annotation_id": "cam_query_[timestamp]"
#   }
# }

set -e

# Read hook input
INPUT=$(cat)
QUERY=$(echo "$INPUT" | jq -r '.query // "unknown"')
RESULTS_COUNT=$(echo "$INPUT" | jq -r '.results_count // 0')
RESULT_SUMMARY=$(echo "$INPUT" | jq -r '.result_summary // "No summary provided"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Skip if CAM not available
if [ ! -d "$CWD/.claude/cam" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Generate annotation ID
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
ANNOTATION_ID="cam_query_${TIMESTAMP}"

# Create annotation summary
PROJECT_NAME=$(basename "$CWD")
ANNOTATION_CONTENT="CAM Query Results

Project: ${PROJECT_NAME}
Query: ${QUERY}
Results Found: ${RESULTS_COUNT}

Summary:
${RESULT_SUMMARY}

Session: ${SESSION_ID:0:8}
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Store in CAM using cam-note.sh
cd "$CWD"
if [ -x ~/.claude/hooks/cam-note.sh ]; then
  SESSION_ID="$SESSION_ID" ~/.claude/hooks/cam-note.sh \
    "CAM Query: ${QUERY}" \
    "$ANNOTATION_CONTENT" \
    "cam-query,session-learning" >/dev/null 2>&1 || true
fi

# Return acknowledgment
jq -n \
  --arg annotation_id "$ANNOTATION_ID" \
  --arg query "$QUERY" \
  --arg results "$RESULTS_COUNT" \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "PostCAMQuery",
      query_annotated: true,
      annotation_id: $annotation_id,
      query: $query,
      results_recorded: ($results | tonumber)
    }
  }'

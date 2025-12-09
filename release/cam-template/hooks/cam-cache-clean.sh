#!/bin/bash
# CAM Cache Cleanup - Remove expired cache entries (30 min TTL)
# Version: 2.0.0
# Usage: cam-cache-clean.sh [optional: clean all]

set -e

CACHE_DIR="$HOME/.claude/.cam-cache"
SESSION_CACHE_FILE="$HOME/.claude/.session-cam-context"
CURRENT_TIME=$(date +%s)
TTL=1800  # 30 minutes in seconds

# If "clean all" argument, remove all cache
if [ "${1:-}" = "clean-all" ]; then
  rm -rf "$CACHE_DIR" 2>/dev/null || true
  rm -f "$SESSION_CACHE_FILE" 2>/dev/null || true
  echo "[v] Cleaned all CAM cache"
  exit 0
fi

# Otherwise, remove only expired entries
if [ ! -d "$CACHE_DIR" ]; then
  exit 0
fi

CLEANED=0

# Remove cache files older than TTL
for cache_file in "$CACHE_DIR"/*; do
  if [ -f "$cache_file" ]; then
    # Get file modification time (portable for Mac/Linux)
    FILE_MTIME=$(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0)
    FILE_AGE=$((CURRENT_TIME - FILE_MTIME))

    if [ "$FILE_AGE" -gt "$TTL" ]; then
      rm "$cache_file" 2>/dev/null || true
      CLEANED=$((CLEANED + 1))
    fi
  fi
done

# Remove session context if it's old
if [ -f "$SESSION_CACHE_FILE" ]; then
  SESSION_MTIME=$(stat -f%m "$SESSION_CACHE_FILE" 2>/dev/null || stat -c%Y "$SESSION_CACHE_FILE" 2>/dev/null || echo 0)
  SESSION_AGE=$((CURRENT_TIME - SESSION_MTIME))

  if [ "$SESSION_AGE" -gt "$TTL" ]; then
    rm "$SESSION_CACHE_FILE" 2>/dev/null || true
  fi
fi

[ "$CLEANED" -gt 0 ] && echo "[v] Cleaned $CLEANED expired cache entries" || true

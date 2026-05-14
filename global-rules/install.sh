#!/usr/bin/env bash
# Install global Claude Code rules by symlinking this directory's CLAUDE.md
# into ~/.claude/CLAUDE.md (user-scope instructions, loaded in every session).
#
# Idempotent. Refuses to overwrite an existing real file or a symlink pointing
# elsewhere — manual action required in that case.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/CLAUDE.md"
LINK="$HOME/.claude/CLAUDE.md"

if [ ! -f "$TARGET" ]; then
  echo "error: $TARGET not found" >&2
  exit 1
fi

mkdir -p "$HOME/.claude"

if [ -L "$LINK" ]; then
  CURRENT="$(readlink "$LINK")"
  if [ "$CURRENT" = "$TARGET" ]; then
    echo "ok: $LINK -> $TARGET (already linked)"
    exit 0
  fi
  echo "error: $LINK is a symlink pointing elsewhere:" >&2
  echo "       $LINK -> $CURRENT" >&2
  echo "       Remove it manually and rerun, or add this line to it:" >&2
  echo "       @$TARGET" >&2
  exit 1
fi

if [ -e "$LINK" ]; then
  echo "error: $LINK exists and is not a symlink." >&2
  echo "       Add this line at the top of it manually instead:" >&2
  echo "       @$TARGET" >&2
  exit 1
fi

ln -s "$TARGET" "$LINK"
echo "ok: linked $LINK -> $TARGET"

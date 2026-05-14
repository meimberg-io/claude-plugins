#!/usr/bin/env bash
#
# install-user-scope.sh
#
# Symlinks every skill, agent, and slash command from this repo's plugins/
# into ~/.claude/skills/, ~/.claude/agents/, ~/.claude/commands/.
#
# Why: the Claude Code plugin marketplace (/plugin install) only works in
# Claude Code Terminal. Surfaces like the Claude Desktop App's Code mode
# read user-scope skills/agents/commands directly from ~/.claude/. This
# script bridges the two — one source of truth (the repo), available in
# both surfaces.
#
# Idempotent. Refuses to overwrite a real file/dir or a symlink that
# already points somewhere else — you have to resolve those manually.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

errors=0

link_one() {
  local src="$1"   # absolute path in the repo
  local dest="$2"  # absolute path under ~/.claude/
  local dest_pretty="${dest/#$HOME/~}"
  local src_pretty="${src/#$HOME/~}"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      echo "  ✓ $dest_pretty (already linked)"
      return 0
    fi
    echo "  ✗ $dest_pretty is a symlink to '$current' — refusing to overwrite." >&2
    return 1
  fi

  if [[ -e "$dest" ]]; then
    echo "  ✗ $dest_pretty exists as a real file/dir — refusing to overwrite. Move or remove it manually." >&2
    return 1
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  + $dest_pretty -> $src_pretty"
}

shopt -s nullglob

for plugin_dir in "$REPO_ROOT"/plugins/*/; do
  plugin_name="$(basename "$plugin_dir")"
  echo "[$plugin_name]"

  # Skills: each is a directory under skills/
  for skill_dir in "$plugin_dir"skills/*/; do
    skill_name="$(basename "$skill_dir")"
    link_one "${skill_dir%/}" "${CLAUDE_DIR}/skills/${skill_name}" || errors=$((errors+1))
  done

  # Agents: each is a *.md file under agents/
  for agent_file in "$plugin_dir"agents/*.md; do
    agent_name="$(basename "$agent_file")"
    link_one "$agent_file" "${CLAUDE_DIR}/agents/${agent_name}" || errors=$((errors+1))
  done

  # Commands: each is a *.md file under commands/
  for cmd_file in "$plugin_dir"commands/*.md; do
    cmd_name="$(basename "$cmd_file")"
    link_one "$cmd_file" "${CLAUDE_DIR}/commands/${cmd_name}" || errors=$((errors+1))
  done
done

echo

if (( errors > 0 )); then
  echo "Finished with $errors conflict(s). Resolve them (rm the conflicting file/symlink) and re-run." >&2
  exit 1
fi

echo "All plugin contents are linked into ~/.claude/."

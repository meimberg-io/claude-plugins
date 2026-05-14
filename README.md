# meimberg/claude-plugins

A personal [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace — own agents/skills plus vetted versions of community ones.

## Use it

### Claude Code Terminal (CLI)

```
/plugin marketplace add meimberg-io/claude-plugins
/plugin install review@meimberg
/plugin install jira@meimberg
```

Update later with `/plugin marketplace update meimberg`.

### Claude Desktop App (Code mode) and other surfaces without `/plugin`

The plugin marketplace (`/plugin install ...`) only works in Claude Code Terminal. Other surfaces (Claude Desktop App's Code mode, etc.) read user-scope skills/agents/commands directly from `~/.claude/`. To make this repo's plugin contents available there, symlink them in:

```bash
git clone git@github.com:meimberg-io/claude-plugins.git ~/workspace/claude-plugins
~/workspace/claude-plugins/install-user-scope.sh
```

The script iterates over every `plugins/*/skills/*`, `plugins/*/agents/*.md`, `plugins/*/commands/*.md` and symlinks each into `~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/commands/`. Idempotent. Refuses to overwrite a real file/dir or a symlink that points elsewhere — resolve manually (`rm` the conflicting entry) and re-run.

Updates are then automatic: `git pull` in this repo updates every linked skill/agent/command in place.

## Plugins

### `review`

PR-review agents vendored from [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (with project-specific examples generalised):

- `silent-failure-hunter` — non-negotiable rules against silent failures, broad catches, undocumented fallbacks; severity-ranked output.
- `code-reviewer` — CLAUDE.md-aware reviewer with 0–100 confidence scoring; reports only issues with confidence ≥ 80 to keep signal:noise high.
- `comment-analyzer` — verifies doc/comment accuracy against actual code, flags comment rot.

Invoked automatically when Claude reasons that a task fits one of them, or you can ask "review this with silent-failure-hunter" / "run a code review on the diff" etc.

### `jira`

Jira workflow skills, all driven by a per-project config at `<repo-root>/.claude/jira.json`.

**First-time setup in a project** — run the setup command, it walks you through everything interactively:

```
/jira-setup
```

It probes the Atlassian MCP for your sites, lists your Jira projects, reconciles git commit prefixes with Jira project keys (they can diverge — e.g. commits `VOLVE-` vs. project `MIVOLVE`), optionally captures custom workflow status names, and writes `.claude/jira.json`. Requires the Atlassian MCP to be connected.

**Then use:**

- `/specify <issue-id>` — turn a Jira issue into a user story with acceptance criteria. Without an ID: batch-mode over the sprint's `Needs Specification` tickets.
- `/implement <issue-id>` — assess + implement (or enter plan mode for complex work), transition through the workflow, commit one focused commit.
- `/commit` — stage all changes and commit with `{Jira-Key}: {Jira-Title}`. Does not push.

These slash commands are thin wrappers around the actual skills (`jira-setup`, `specify`, `implement`, `commit`). The skills also auto-trigger when you describe what you want in natural language ("commit", "implementiere VOLVE-42", "jira einrichten") — slash commands are mainly for discoverability via autocomplete.

The schema for `.claude/jira.json`:

```json
{
  "projectKey": "MIVOLVE",
  "cloudId": "86465bd6-9d7f-4194-91ab-eea3a8e1f976",
  "site": "https://meimberg.atlassian.net",
  "commitPrefix": "VOLVE-",
  "statusNames": {
    "spec": "Needs Specification",
    "ready": "Ready to implement",
    "inProgress": "In Arbeit",
    "done": "Fertig"
  }
}
```

`projectKey`, `cloudId`, `site` are required; `commitPrefix` defaults to `<projectKey>-`; `statusNames` is only needed if the project uses non-default workflow names.

## Global rules

Cross-cutting behavioral rules that should apply in *every* Claude Code session, project-independent. Lives outside the plugin marketplace because plugins have no auto-loading instructions primitive — instead, a symlink wires `global-rules/CLAUDE.md` into `~/.claude/CLAUDE.md` (user-scope instructions, loaded in every session).

Setup on a new machine:

```bash
git clone git@github.com:meimberg-io/claude-plugins.git ~/workspace/claude-plugins
~/workspace/claude-plugins/global-rules/install.sh
```

The install script is idempotent and refuses to overwrite an existing real file or a symlink pointing elsewhere.

Add a new rule:

1. Drop a markdown file into `global-rules/<category>/<rule-name>.md`.
2. Reference it from `global-rules/CLAUDE.md` via `@<category>/<rule-name>.md`.

## Layout

```
.
├── .claude-plugin/
│   └── marketplace.json          # registry — lists every plugin in this repo
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json       # plugin manifest
│       ├── agents/               # *.md agents
│       ├── skills/               # skill folders (SKILL.md + assets)
│       ├── commands/             # slash commands
│       └── hooks/                # optional hooks
├── global-rules/
│   ├── CLAUDE.md                 # aggregator — symlinked into ~/.claude/CLAUDE.md
│   ├── install.sh                # creates the symlink
│   └── <category>/<rule>.md      # individual rule files, imported via @
└── README.md
```

## Adding a new plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json`.
2. Drop agents into `plugins/<name>/agents/`, skills into `plugins/<name>/skills/`, etc.
3. Append an entry to `.claude-plugin/marketplace.json`.
4. Commit & push — `/plugin marketplace update meimberg` picks it up.

## Conventions

- **Own work**: author = Oliver Meimberg, no source attribution needed.
- **Adapted from elsewhere**: keep the upstream attribution as a footer in the file (see `review/agents/silent-failure-hunter.md` for the pattern). Don't vendor unmodified — fork the file into this repo so changes don't drift.

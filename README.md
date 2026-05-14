# meimberg/claude-plugins

A personal [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace — own agents/skills plus vetted versions of community ones.

## Use it

```bash
# in Claude Code
/plugin marketplace add meimberg-io/claude-plugins
/plugin install architects@meimberg
/plugin install jira@meimberg
```

Update later with `/plugin marketplace update meimberg`.

## Plugins

### `architects`

Architecture-review agent (SOLID, boundaries, dependencies). Use via the agent picker or by asking Claude to review a change for architectural fit.

### `jira`

Jira workflow skills, all driven by a per-project config at `<repo-root>/.claude/jira.json`.

**First-time setup in a project** — run the setup skill, it walks you through everything interactively:

```
/skill jira-setup
```

It probes the Atlassian MCP for your sites, lists your Jira projects, reconciles git commit prefixes with Jira project keys (they can diverge — e.g. commits `VOLVE-` vs. project `MIVOLVE`), optionally captures custom workflow status names, and writes `.claude/jira.json`. Requires the Atlassian MCP to be connected.

**Then use:**

- `/skill specify <issue-id>` — turn a Jira issue into a user story with acceptance criteria.
- `/skill implement <issue-id>` — assess + implement (or enter plan mode for complex work), transition through the workflow.
- `/skill commit` — stage all changes and commit with `{Jira-Key}: {Jira-Title}`. Does not push.

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
- **Adapted from elsewhere**: keep the upstream attribution as a footer in the file (see `architects/agents/architect-review.md` for the pattern). Don't vendor unmodified — fork the file into this repo so changes don't drift.

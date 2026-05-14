---
name: commit
description: Stage and commit all changes with a "{Jira-Key}: {Jira-Title}" message. Use when the user asks to commit (e.g. "commit", "committen", "commit die Änderungen"). Resolves the Jira key from the user message, then conversation context, then current git branch, then most recent commit prefix. Project key and cloudId are resolved from the project's .claude/jira.json. Does not push.
---

# Commit (Jira)

Stage and commit all current changes with message `{Jira-Key}: {Jira-Title}`. **Does not push.**

## When to use

When the user asks to commit ("commit", "committen", "commit die Änderungen"). Typical case: same chat where a Jira ticket was just implemented — use that ticket's key for the commit message without the user repeating it. Never commit without an explicit ask.

## Workflow

### 0. Resolve project context

Look up the current project's Jira context in this order:

1. **`<repo-root>/.claude/jira.json`** (preferred). Required fields: `projectKey`, `cloudId`, `site`. Optional: `commitPrefix`, `statusNames`. Full schema and setup live in the `jira-setup` skill.
2. **Legacy fallback:** `## Jira` section in `<repo-root>/CLAUDE.md`. If found and `.claude/jira.json` is missing, tell the user to run `jira-setup` to migrate, then stop.
3. **Neither exists:** tell the user to run the `jira-setup` skill first, then retry. Do **not** bootstrap inline.

### 1. Resolve the Jira issue key

Try in order. Match against **both** the Jira `projectKey` and the `commitPrefix` (when set), since branches/commits may use the commit prefix while Jira API calls need the Jira key:

1. **User's message** — explicit key (`"commit <PREFIX>-44"`) or bare number (`"commit 44"`).
2. **Conversation context** — the ticket implemented or referenced earlier in this chat.
3. **Current git branch** — match `(<projectKey>|<commitPrefix>)\d+` (case-insensitive) in the branch name.
4. **Most recent commit** — `git log -1 --pretty=%s` and extract a `(<projectKey>|<commitPrefix>)\d+` prefix.
5. **Bare number in message** → prefix with the Jira `projectKey` for the API call. Use `commitPrefix` for the commit message.
6. If still unknown: ask.

### 2. Get the Jira title

- Call `getJiraIssue` with `{ cloudId, issueIdOrKey }`. Use `fields.summary` as the title.
- If the fetch fails: report and stop (or ask the user for a manual message).

### 3. Build the commit message

Format: `{commitPrefix}{n}: {summary}` — use `commitPrefix` from `## Jira` if set; otherwise default to `<projectKey>-`. The commit-side key may differ from the Jira-side key (e.g. commit `VOLVE-133` for Jira issue `MIVOLVE-133`).

Example: `VOLVE-133: Der Content sollte die volle Breite nutzen`

- No body, no extra newline — unless the user explicitly asks for one. Match the project's recent `git log` style if it differs (some projects include Co-Authored-By footers, others don't).
- Use the summary as Jira returns it (no truncation unless very long; then truncate sensibly).

### 4. Commit (no push)

1. From repo root: `git status -s`. If nothing to commit, report and stop.
2. Stage: `git add -A` (default — stage everything). If the user prefers only already-staged files, skip this step.
3. Commit: `git commit -m "<message>"`. **Do not** push.

## Atlassian MCP — call shapes

- `getJiraIssue` — `{ cloudId, issueIdOrKey }` → `fields.summary` is the title.

## Hard rules

- **No** `--no-verify`, **no** `--force` — unless the user explicitly requests it.
- **No** `git push`. This skill never pushes.
- If a pre-commit hook fails: fix the underlying issue, re-stage, and create a **new** commit. Never `--amend` past a hook failure (the original commit didn't happen).
- Never hardcode a project key or cloudId. Resolve from `.claude/jira.json` per project.

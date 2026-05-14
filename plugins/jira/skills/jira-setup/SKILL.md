---
name: jira-setup
description: Interactive bootstrap for the project's Jira config. Resolves the Atlassian site (cloudId), picks the Jira project, optionally captures a separate commit prefix and custom workflow status names, then writes `.claude/jira.json`. Use when a project doesn't yet have a `.claude/jira.json`, when the user says "set up Jira" / "configure Jira" / "Jira einrichten", or when one of the Jira workflow skills (commit / implement / specify) bootstraps a new project.
---

# Jira Setup

One-shot interactive bootstrap that produces `<repo-root>/.claude/jira.json` for this project. The `commit`, `implement`, and `specify` skills depend on this file — running this skill once per project replaces their inline bootstrap.

## When to use

- Project has no `.claude/jira.json` yet and the user wants to use any Jira skill here.
- User explicitly asks to set up / re-configure Jira for this project.
- Existing config is wrong (e.g. wrong `projectKey` after a Jira project rename) and needs to be regenerated.

## Pre-flight

1. Check `<repo-root>/.claude/jira.json`. If it exists, show the current config and ask whether to **overwrite**, **edit a single field**, or **abort**.
2. Check `<repo-root>/CLAUDE.md` for a legacy `## Jira` section. If found, offer to migrate its values as defaults; do **not** mutate `CLAUDE.md`.
3. Confirm the user is signed into the Atlassian MCP. If `getAccessibleAtlassianResources` returns nothing or errors, stop and tell the user to authenticate first (`/connect atlassian` or the plugin's authenticate flow).

## Walkthrough

### 1. Resolve the site (`cloudId` + `site`)

- Call `getAccessibleAtlassianResources`. Each entry has `{ id (=cloudId), name, url }`.
- **One site** → auto-pick, show it to the user, ask to confirm.
- **Multiple sites** → list them numbered, ask the user to pick.

### 2. Resolve the Jira project (`projectKey`)

- With the chosen `cloudId`, call `getVisibleJiraProjects`. Each entry has `{ key, name }`.
- Pre-select hint: run `git log --oneline -30` in the repo and look for `[A-Z]+-\d+:` prefixes. Show the inferred prefix **alongside** the real Jira project keys so the user can see both — git prefix and Jira key may diverge (e.g. commits use `VOLVE-` but the Jira project is `MIVOLVE`).
- Ask the user to pick the Jira project. Default to the match if the git prefix matches a project key exactly.
- **Validate**: call `searchJiraIssuesUsingJql` with `{ cloudId, jql: "project = <KEY>", maxResults: 1 }`. If it errors with "project doesn't exist" / similar, re-ask.

### 3. Resolve the commit prefix (`commitPrefix`, optional)

- If the inferred git prefix from step 2 equals `<projectKey>-`, skip this — `commitPrefix` defaults to `<projectKey>-`.
- If they differ, ask: "Commits in this repo use `<inferred>-`, but the Jira project is `<projectKey>`. Use `<inferred>-` for commit messages?" Default yes. Store as `commitPrefix`.

### 4. Resolve workflow status names (`statusNames`, optional)

- Defaults: `Needs Specification`, `Ready to implement`, `In Arbeit`, `Fertig`.
- Ask: "Does this project use the default workflow status names (Needs Specification → Ready to implement → In Arbeit → Fertig)?" Default yes — skip writing `statusNames` if so.
- If no: ask for each of the four names. Allow the user to skip any (means: that step doesn't exist in this workflow). Store only the keys the user provided.

### 5. Confirm and write

- Print the resulting JSON to the user. Ask "Save to `.claude/jira.json`?"
- On confirmation:
  - Create `.claude/` if it doesn't exist.
  - Write `.claude/jira.json` with 2-space indentation, trailing newline.
  - If a legacy `## Jira` section exists in `CLAUDE.md`, suggest the user remove it (do not auto-edit).
- Done. Mention that `commit`, `implement`, `specify` are now ready to use in this project.

## Schema

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

- `projectKey`, `cloudId`, `site` — **required**.
- `commitPrefix` — optional, defaults to `<projectKey>-`.
- `statusNames` — optional; omit entirely if defaults are used.

## Required MCP tools

- `getAccessibleAtlassianResources` — `{}` → sites with `{ id, name, url }`.
- `getVisibleJiraProjects` — `{ cloudId }` → projects with `{ key, name }`.
- `searchJiraIssuesUsingJql` — `{ cloudId, jql, maxResults }` (used here only for validation).

## Guardrails

- Never write `.claude/jira.json` without explicit user confirmation of the final JSON.
- Never mutate `CLAUDE.md`.
- Never hardcode values — every field comes from the Atlassian API or an explicit user answer.
- `cloudId` is per-site, not per-project. Don't ask the user to "enter the cloudId" — derive it from `getAccessibleAtlassianResources`.

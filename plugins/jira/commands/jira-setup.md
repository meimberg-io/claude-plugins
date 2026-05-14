---
description: Interactively configure Jira for this project — writes .claude/jira.json.
---

Run the **jira-setup** skill to configure Jira for the current project.

The skill will:
1. Probe the Atlassian MCP for accessible sites and resolve `cloudId`.
2. List visible Jira projects and reconcile them with any git commit-prefix hints.
3. Validate the chosen project key, optionally capture a separate `commitPrefix` and custom workflow status names.
4. Write the result to `<repo-root>/.claude/jira.json` after explicit confirmation.

If `.claude/jira.json` already exists, ask whether to overwrite, edit a single field, or abort.

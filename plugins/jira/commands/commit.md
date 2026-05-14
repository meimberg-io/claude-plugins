---
description: Stage all changes and commit with "{Jira-Key}: {Jira-Title}". Does not push.
---

Run the **commit** skill.

Arguments: `$ARGUMENTS`

Resolve the Jira key in this order: arguments → conversation context → current git branch → most recent commit prefix. Fetch the Jira summary, then `git add -A` and commit with `{commitPrefix}{n}: {summary}`. Never push.

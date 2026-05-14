---
description: Turn a Jira issue into a user story with acceptance criteria. Optional issue ID; without one, processes the sprint's "Needs Specification" tickets.
---

Run the **specify** skill.

Arguments: `$ARGUMENTS`

If an issue ID was provided, specify that single ticket. If not, enter batch mode and process all tickets in `Needs Specification` status that are assigned to any sprint (active or future), one at a time, waiting for the user's answers between tickets.

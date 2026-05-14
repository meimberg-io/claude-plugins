---
name: implement
description: Implements a specified Jira ticket. Reads the ticket spec, assesses complexity, transitions to "In Arbeit", then either implements directly or enters Plan mode for complex/ambiguous work. Use when the user wants to implement, build, or start working on a Jira ticket. Project key and cloudId are resolved from the project's .claude/jira.json.
---

# Implement (Jira Ticket → Assess → Implement or Plan)

Read a specified Jira ticket, assess whether it can be implemented directly or needs planning, then either implement or enter Plan mode. Transitions the ticket through the workflow.

## Scope

- **In scope:** Read ticket (`getJiraIssue`), assess complexity, transition to **"In Arbeit"** (`getTransitionsForJiraIssue` / `transitionJiraIssue`), implement code changes or enter Plan mode, follow project rules (`CLAUDE.md` and any binding docs it links to), transition to **"Fertig"**, then commit (one commit per ticket).
- **Out of scope:** `git push` (only on explicit user request).

## Workflow (strict order)

### 0. Resolve project context

Look up the current project's Jira context in this order:

1. **`<repo-root>/.claude/jira.json`** (preferred). Required fields: `projectKey`, `cloudId`, `site`. Optional: `commitPrefix`, `statusNames`. Full schema and setup live in the `jira-setup` skill.
2. **Legacy fallback:** `## Jira` section in `<repo-root>/CLAUDE.md`. If found and `.claude/jira.json` is missing, tell the user to run `jira-setup` to migrate, then stop.
3. **Neither exists:** tell the user to run the `jira-setup` skill first, then retry. Do **not** bootstrap inline.

Cache the resolved config for the rest of the session.

### 1. Resolve the issue key

- From the user message (`"<KEY>-42"`, `"ticket 42"`, `"implementiere 42"`). If only a number, prefix with the resolved Jira key.
- If missing or ambiguous: ask.

### 2. Fetch and understand the ticket

- Call `getJiraIssue` with `{ cloudId, issueIdOrKey }`.
- **Sanity check the returned key.** If the response's `key` differs from what was requested (Jira may alias an old project key to the current one), surface this to the user and treat the response key as authoritative.
- If the fetch fails: report and stop.
- Extract: `summary`, `description` (user story, acceptance criteria, decisions), `status`, `issuetype`, `priority`.
- If the ticket has **no spec / no acceptance criteria** → suggest running `/specify` first and stop.

### 3. Read the binding docs first

Before touching code, consult the project's `CLAUDE.md` for a "Binding Project Documentation" / "Single Source of Truth" section. Read whatever it points to that's relevant to this ticket (schema docs, auth docs, frontend guidelines, API contracts, etc.). If `CLAUDE.md` doesn't list any, fall back to the obvious candidates in the repo (`docs/`, `README.md`).

### 4. Assess complexity

**Implement directly** when:
- Acceptance criteria are clear.
- Scope well-defined (single component, isolated change, known pattern).
- No unresolved conceptual questions.
- Touches ≤ 3–4 files.

**Enter Plan mode** when:
- Multiple valid implementation approaches with trade-offs.
- Architectural decisions needed (new patterns, data-model changes, cross-cutting concerns).
- Scope is large (many files, multiple systems).
- Acceptance criteria are ambiguous or conflicting.
- The user explicitly asks for a plan.

### 5. Transition to "In Arbeit"

- Call `getTransitionsForJiraIssue` with `{ cloudId, issueIdOrKey }`.
- Find the transition whose `to.name` is **"In Arbeit"** (or the project's equivalent — see "Status name overrides" below).
- Call `transitionJiraIssue` with `{ cloudId, issueIdOrKey, transition: { id: "<id>" } }`.
- If unavailable (e.g. already in progress): note and continue.

### 6a. Direct implementation

- Briefly summarise the ticket and your approach in chat.
- Use TodoWrite to track multi-step work.
- Implement following project rules (CLAUDE.md and any binding docs).
- Run typecheck/build/tests; fix until clean.

### 6b. Plan mode

- Briefly explain *why* planning is needed ("multiple approaches", "architectural decision").
- Enter Plan mode (use the EnterPlanMode tool). Present the ticket context, outline implementation options with trade-offs, and ask the user for direction.

### 7. Transition to "Fertig"

- Find the transition whose `to.name` is **"Fertig"** (or the project's equivalent — see "Status name overrides" below) via `getTransitionsForJiraIssue`, then call `transitionJiraIssue`.
- Skip when implementation didn't complete or the user paused mid-ticket.

### 8. Commit (one commit per ticket)

- Stage **only** the files this ticket touched — by explicit path. Do **not** use `git add -A` / `git add .`. Skip build artefacts (e.g. `tsconfig.tsbuildinfo`) and pre-existing unrelated modifications.
- Commit message format mirrors typical history: `<PREFIX><n>: <Jira-Summary-verbatim>` (e.g. `VOLVE-133: Der Content sollte die volle Breite nutzen`). Use `commitPrefix` from `## Jira` if set; otherwise default to `<projectKey>-`. No body, no Co-Authored-By footer — unless the project's recent `git log` shows a different convention, in which case match the project.
- One commit per ticket — for multi-ticket batches (`/implement C5`), checkpoint and commit after each ticket before starting the next, so each commit is a clean per-ticket diff.
- Never `git push` — the user owns publishing.
- After: brief summary of what was done and which files changed.

## Status name overrides

If the project's workflow uses different status names than the defaults (`Needs Specification`, `Ready to implement`, `In Arbeit`, `Fertig`), declare them in `.claude/jira.json` under `statusNames`. When absent, use the defaults above.

**Transition IDs are project-specific and must NOT be hardcoded** — always look them up via `getTransitionsForJiraIssue` and match by `to.name`.

## Atlassian MCP — call shapes (avoid common pitfalls)

- **All calls require `cloudId`.** Resolved per project from `.claude/jira.json` (or bootstrap). Cache for the session.
- `getJiraIssue` — `{ cloudId, issueIdOrKey }`
- `editJiraIssue` — `{ cloudId, issueIdOrKey, fields: { description: "<markdown>", summary?: "<text>" } }`
   - Description is **markdown** — the MCP server converts to ADF. Do **not** send raw ADF JSON.
   - Encoding pitfall: certain non-ASCII glyphs (German guillemets `„…"`, `€`, arrows `↔ → ↗`) can trigger `Expected object, received string` on the `fields` path. Sanitise to ASCII (`"`, `EUR`, `->`) or `\uXXXX`-escape, then retry. See `/specify` § 6.
- `searchJiraIssuesUsingJql` — `{ cloudId, jql }`
- `getTransitionsForJiraIssue` — `{ cloudId, issueIdOrKey }` → `{ transitions: [{ id, name, to: { name } }] }`
- `transitionJiraIssue` — `{ cloudId, issueIdOrKey, transition: { id: "<transitionId>" } }` (nested object, **not** top-level `transitionId`)

## Hard rules

- **Do not** run `git push` unless the user explicitly asks.
- **Do not** start work on tickets outside the current sprint or outside "Ready to implement" without an explicit user direction.
- **Do not** lump multiple tickets into one commit — one ticket = one commit, even within a batch.
- **Never** hardcode project key, cloudId, or transition IDs. Resolve project context from `.claude/jira.json`; resolve transitions dynamically.

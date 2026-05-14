---
name: specify
description: Improves a Jira issue by turning it into a user story with acceptance criteria. Reads the issue, drafts user story + criteria, asks the user conceptual questions in chat, incorporates answers, then saves the finalized spec to Jira and transitions to "Ready to implement". No code changes. When no issue ID is given, processes all "Needs Specification" tickets in an open sprint one by one. Project key and cloudId are resolved from the project's .claude/jira.json.
---

# Specify (Jira — User Story → Fragen → Finalisieren → Jira)

Improve a Jira issue's specification without touching code. Workflow: resolve project context → read issue → conceive fully → ask user conceptual questions in chat → incorporate answers → save finalized spec to Jira → transition to "Ready to implement".

## Scope

- **In scope:** Read issue (`getJiraIssue`), draft user story + acceptance criteria, identify open conceptual questions, ask the user, incorporate answers, update issue (`editJiraIssue`), transition to "Ready to implement" (`transitionJiraIssue`).
- **Out of scope:** Any code, config, or repo file changes. No implementation. No `git commit` / `git push`.

## Workflow (strict order)

### 0. Resolve project context

Look up the current project's Jira context in this order:

1. **`<repo-root>/.claude/jira.json`** (preferred). Required fields: `projectKey`, `cloudId`, `site`. Optional: `commitPrefix` (defaults to `<projectKey>-`), `statusNames`. Full schema and setup live in the `jira-setup` skill.
2. **Legacy fallback:** `## Jira` section in `<repo-root>/CLAUDE.md` (older projects). If found and `.claude/jira.json` is missing, tell the user to run `jira-setup` to migrate, then stop.
3. **Neither exists:** tell the user to run the `jira-setup` skill first, then retry. Do **not** bootstrap inline.

Cache the resolved config (`projectKey`, `cloudId`, `site`, `commitPrefix`, `statusNames`) for the rest of the session.

### 1. Resolve the issue key

- From the user message (`"<KEY>-42"`, `"ticket 42"`). If only a number, prefix with the resolved project key (`"42"` → `"<KEY>-42"`).
- **If no key given:** enter **batch mode** (see section below).

### 2. Fetch and understand the issue

- Call `getJiraIssue` with `{ cloudId, issueIdOrKey }`.
- If fetch fails: report and stop.
- Read summary, description, any existing acceptance criteria.
- **Sanity check the returned key.** If the response's `key` differs from what was requested (Jira sometimes aliases an old project key to the current one — e.g. requesting `VOLVE-94` returns `MIVOLVE-94`), surface this to the user and treat the response key as authoritative for follow-up calls.

### 2.5. Status check — already specified?

- If `status.name` is **not** `"Needs Specification"` (or the project's equivalent), **and** the description is non-empty / has acceptance criteria, the ticket is already specified.
- **Stop and ask the user** before drafting a new spec:
  - Show the current status, summary, and a hint that the description already exists (e.g. "Spec-Version 2026-03-15 v3 vorhanden").
  - Offer: (a) **abort** — wrong ticket, (b) **edit punctually** — tell me what to change, I'll diff/edit, (c) **rewrite** — draft a fresh spec and overwrite (only on explicit "rewrite"/"komplett neu" instruction).
- Only proceed to step 3 when the user picks (b) or (c). For (b), skip the conceive-fully draft and ask for the specific changes instead.

### 3. Conceive fully

- Draft **user story (German):** "Als … möchte ich … damit …"
- Draft **acceptance criteria:** concrete, testable bullets.
- Identify **open conceptual questions** (scope, data model, UX, product decisions) that need the user's input before the spec is final.

### 4. Ask the user (do not update Jira yet)

- In chat: present the draft user story + acceptance criteria briefly.
- List the **conceptual questions** clearly and ask the user to answer them — or to say "save as-is" / "ohne Antworten speichern" if they want the spec saved with open questions written into the issue.
- **Do not** call `editJiraIssue` in this step. Wait for the user's answers.

### 5. Incorporate answers and finalize

- Once the user has answered (or said "as-is"): integrate answers into the spec — turn decisions into a short **Entscheidungen** section or fold them into criteria; reduce or drop questions that are now resolved.
- Produce the **final issue description**.

### 6. Save spec to Jira

- Call `editJiraIssue` with `{ cloudId, issueIdOrKey, fields: { description: "<markdown>", summary?: "<text-if-changed>" } }`.
- Description is **markdown** — the MCP server converts to ADF. Never send raw ADF JSON.
- The spec MUST land in the **description**. Do not write it as a comment — `/implement` reads the description.

#### Encoding pitfall: `editJiraIssue.fields` rejected with "Expected object, received string"

`editJiraIssue` may fail with `Expected object, received string` on the `fields` path when the payload contains certain Unicode characters. Observed triggers: German guillemets (`„…"`), single guillemets (`‚…'`), the euro symbol `€`, and arrow glyphs (`↔ ↗ →`). The MCP bridge appears to abort JSON-parsing on these sequences and forward `fields` as a raw string, which the server's Zod validator then rejects.

**Sanitise and retry — do NOT fall back to a comment:**

1. Replace smart/typographic quotes with ASCII straight quotes (`"` and `'`).
2. Replace `€` with `EUR`.
3. Replace arrow glyphs with `->`, `<->`, etc.
4. If problematic characters are unavoidable (e.g. in user-facing copy), encode them as `\uXXXX` escapes inside the JSON string literal.
5. Retry `editJiraIssue` with the sanitised payload.

If it still fails after sanitisation, surface the exact payload and error to the user and ask. **Never** write the spec as a comment — the description is the contract for `/implement`.

Earlier versions of this skill blamed an "open-shape" MCP bridge bug and prescribed a comment fallback. That diagnosis was wrong (confirmed 2026-05-12 — short `fields` payloads with simple ASCII work fine; the failures correlate with non-ASCII glyphs, not with the schema shape). If you encounter legacy tickets where the spec lives in a comment, migrate it into the description on the next touch.

### 7. Transition to "Ready to implement"

- Call `getTransitionsForJiraIssue` with `{ cloudId, issueIdOrKey }`.
- Find the transition whose `to.name` is **"Ready to implement"** (or the project's equivalent — see "Status name overrides" below).
- Call `transitionJiraIssue` with `{ cloudId, issueIdOrKey, transition: { id: "<id>" } }`.
- If unavailable (e.g. issue not in "Needs Specification"): warn the user but don't fail — the spec from step 6 is still saved.
- Confirm with the issue link (build from Atlassian site: `https://<site>/browse/<KEY>-<n>`) and the new status.

## Output format

### When asking questions (step 4)

In chat, show:
- Short summary of current understanding
- Draft **user story** + **acceptance criteria**
- Numbered list of **conceptual questions**, then ask for answers

### Final issue description (step 6)

Use Jira-compatible markdown. Template:

```
## User Story
**Als** … **möchte ich** … **damit** …

## Quelle der Wahrheit
- docs/requirements/<file>.md (relevant section)

## Akzeptanzkriterien
1. …
2. …

## Entscheidungen
- …

---
_Spec-Version: YYYY-MM-DD._
```

If the user saved "as-is", keep a **Konzeptionell offene Fragen** section in the description.

## Batch mode (no issue key given)

When invoked without an issue key, process tickets in **"Needs Specification"** sitting in **any sprint** (active or future, not just the currently running one). **Exclude backlog** (tickets without any sprint assignment).

### Batch JQL

```
project = <KEY> AND status = "Needs Specification" AND sprint is not EMPTY ORDER BY rank ASC
```

Substitute `<KEY>` with the resolved project key.

Rationale: sprints are often planned in advance — spec tickets in upcoming sprints before they become active. `openSprints()` would hide them.

Only narrow to `sprint in openSprints()` if the user explicitly says "nur aktiver Sprint" / "current sprint only".

If no results: say so explicitly (e.g. "Nichts in 'Needs Specification' in einem Sprint") and stop. Do **not** widen to backlog unless the user asks.

### Batch workflow

1. **Search:** Call `searchJiraIssuesUsingJql` with the JQL above. If no results, tell the user and stop.
2. **List:** Show a numbered overview of all found tickets (key + summary) so the user knows what's coming.
3. **Process one at a time:** For each ticket, run the normal workflow (steps 2–7). Crucially:
   - Present **one** ticket. Show key, summary, draft spec + questions.
   - **Wait** for the user's answers before saving and moving to the next.
   - After saving, confirm the link + transition, then announce which ticket comes next.
4. **Skip:** User says "skip" / "überspringen" → move on without changes.
5. **Stop:** User says "stop" / "fertig" → end the batch. Confirm how many tickets were processed.
6. **Summary:** After all tickets (or stop): brief summary — specified / skipped / remaining.

## Status name overrides

If the project's workflow uses different status names than the defaults (`Needs Specification`, `Ready to implement`, `In Arbeit`, `Fertig`), declare them in `.claude/jira.json` under `statusNames`. When absent, use the defaults above.

## Atlassian MCP — call shapes (avoid common pitfalls)

- **All calls require `cloudId`.** Resolved per project from `.claude/jira.json` (or bootstrap). Cache for the session.
- `getJiraIssue` — `{ cloudId, issueIdOrKey }`
- `editJiraIssue` — `{ cloudId, issueIdOrKey, fields: { description: "<markdown>", summary?: "<text>" } }`
   - **Description is markdown.** The MCP server converts to ADF. Sending raw ADF JSON triggers "Failed to convert markdown to adf".
   - **Encoding pitfall:** certain non-ASCII glyphs (German guillemets `„…"`, `€`, arrows `↔ → ↗`) can trigger `Expected object, received string`. Sanitise to ASCII (`"`, `EUR`, `->`) or use `\uXXXX` escapes, then retry. See § 6.
- `addCommentToJiraIssue` — `{ cloudId, issueIdOrKey, commentBody, contentFormat?: 'markdown' }`. Used for follow-up comments (e.g. functional-test screenshots), **not** as a fallback for the spec itself.
- `searchJiraIssuesUsingJql` — `{ cloudId, jql }`
- `getTransitionsForJiraIssue` — `{ cloudId, issueIdOrKey }` → `{ transitions: [{ id, name, to: { name } }] }`
- `transitionJiraIssue` — `{ cloudId, issueIdOrKey, transition: { id: "<transitionId>" } }` (nested object, **not** top-level `transitionId`)

## Hard rules

- **No** code or config changes — this skill is spec-only.
- **No** `git commit` / `git push`.
- Always wait for the user's answers in step 4 before calling `editJiraIssue`.
- Never hardcode a project key or cloudId. Resolve from `.claude/jira.json` per project.

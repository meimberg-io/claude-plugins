# Regeln dauerhaft machen — User-Wünsche ins Repo schreiben

Sobald der User formuliert, dass eine Verhaltensweise *in Zukunft* gelten soll — typische Trigger-Phrasen:

- „Nimm das in deine Regeln auf"
- „Merk dir das"
- „Mach das in Zukunft immer so"
- „Ab jetzt …"
- „Ich möchte, dass du von jetzt an …"
- „Das soll generell gelten"
- „Achte ab sofort darauf, dass …"

…ist die Aufgabe **nicht** durch bloßes Berücksichtigen in der laufenden Session erledigt. Die Regel muss ins Repo, sonst geht sie spätestens mit der nächsten Session verloren.

## How to apply

1. **Kategorie wählen** in `~/workspace/claude-plugins/global-rules/`. Bestehende Kategorien:
   - `coding/` — Code-Qualität, Architektur, Lib-Design
   - `meta/` — Regeln darüber, *wie* ich Regeln und Workflows handhabe (z. B. diese Datei hier)
   
   Wenn nichts passt, neue Kategorie anlegen — z. B. `commits/`, `communication/`, `testing/`, `documentation/`.

2. **Datei anlegen** unter `global-rules/<category>/<kurzer-kebab-name>.md`. Format: H1-Titel, kurzer Aufhänger („wann gilt diese Regel"), dann Abschnitte `## How to apply` (konkrete Schritte / Trigger-Bedingungen) und `## Why` (Begründung). Bei Bedarf `## Abgrenzung` für Sonderfälle.

3. **Aggregator updaten**: `global-rules/CLAUDE.md` um den `@<category>/<datei>.md`-Import erweitern. Wenn die Kategorie neu ist, eigene H2-Section anlegen.

4. **Beim User rückbestätigen**: kurz zeigen, welche Datei angelegt wurde und welche Trigger-Phrasen drinstehen. So kann der User korrigieren, falls die Formulierung den Wunsch nicht trifft.

5. **Nichts in `~/.claude/CLAUDE.md` direkt schreiben.** Das ist nur ein Symlink. Quelle ist immer `global-rules/` im Repo.

6. **Committen**, nicht uncommitted liegen lassen. Eine ungetrackte Regel-Datei drift weg.

## Why

- **Versionskontrolle**: jede Regel bekommt einen Commit mit Begründung, ist diskutierbar, refactorbar, deprecation-fähig.
- **Geteilt zwischen Maschinen**: via `git pull` + Symlink — kein manuelles Nachpflegen.
- **Drift-Schutz**: Verhaltensregeln, die nur als „Konversations-Memory" existieren, verschwinden bei der nächsten Session oder beim Wechsel zwischen Surfaces (Desktop App ↔ CLI). Im Repo lebt die Regel an einem Ort und wirkt überall.
- **Auditierbar**: Wettbewerbsvorteil eines Software-Dienstleisters ist das kuratierte Skillset (siehe Blog-Draft `docs/blog-draft.md`). Regeln sind Teil davon — sie gehören versioniert, nicht ad-hoc gemerkt.

## Abgrenzung

- **Verhaltensregel** (Stil, Vorgehen, Konvention) → diese Methode (`global-rules/`).
- **Harte Automatisierung** („vor jedem Commit X ausführen", „on stop notify") → Hook in `~/.claude/settings.json` via `update-config`-Skill, nicht hierher.
- **Projektspezifische Regel** (gilt nur in *einem* Repo) → das jeweilige `<projekt>/CLAUDE.md`, nicht `global-rules/`. Bei Unklarheit kurz nachfragen, ob global oder projektbezogen gemeint ist.
- **Skill-spezifisches Verhalten** („der commit-Skill soll X anders machen") → die jeweilige `SKILL.md` im Marketplace-Repo, nicht globale Regel.

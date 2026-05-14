# Skills, Plugins, Agents: Wie ein Software-Dienstleister sein wichtigstes Asset organisiert

## Worum es eigentlich geht

In fünf Jahren werden Software-Dienstleister daran gemessen, wie gut ihr kollektives Skillset für KI-gestützte Entwicklung ist. Drei konkurrierende Companies werden vor demselben Anforderungsdokument denselben Workflow starten — Anforderungen kippen, durch Spec-Skills jagen, Code generieren, Architecture-Reviews fahren, Tests bauen, deployen. Der Workflow ist austauschbar. Was nicht austauschbar ist: das jahrelang kollaborativ kuratierte Set an Agents, Skills und Plugins, das jeden dieser Schritte präziser, schneller und projektgerechter macht. Wer hier zehn Mannjahre Vorsprung hat, baut mit weniger Aufwand bessere Software. Das ist der eigentliche Wettbewerbsvorteil — und er sitzt in einem einzigen Git-Repo.

Dieser Artikel beschreibt, wie man dieses Repo aufsetzt, organisiert und in Projekten anwendet — am Beispiel von Claude Code, aber das Konzept überträgt sich auf jeden vergleichbaren Agent-Runner.

---

## Drei Ebenen, auf denen Claude Code Skills lädt

Bevor wir ein Repo bauen, müssen wir wissen, wo der Agent überhaupt sucht. Claude Code kennt drei Scopes — kommt automatisch, keine Registrierung nötig:

| Scope | Ort | Wofür |
|---|---|---|
| **User (global)** | `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/commands/` | Was du in *jedem* Projekt brauchst — dein Standard-Werkzeugkasten |
| **Project** | `<projekt>/.claude/...` | Projektspezifisch, in Git eingecheckt, fürs Team |
| **Project local** | `<projekt>/.claude/...` mit `.gitignore` | Persönliche Experimente |

Wer einfach Dateien direkt in diese Ordner kippt, landet schnell im Wildwuchs: Skills veralten, Kollegen wissen nicht woher die Datei kommt, Updates passieren nirgends. Deshalb braucht es eine vierte Ebene: **das Plugin-System**.

## Plugins und Marketplaces — der Paketmechanismus

Ein **Plugin** ist ein Ordner, der eine Sammlung zusammengehöriger Agents, Skills, Slash-Commands, Hooks und ggf. MCP-Server bündelt. Ein **Marketplace** ist ein Git-Repo, das mehrere Plugins listet. Installation und Updates laufen über `git pull` im Marketplace-Cache — keine Copy-Paste-Drift.

Damit wird das eigene Marketplace-Repo zum *Single Source of Truth* für das gesamte Firmen-Skillset.

## Repo-Struktur

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json          # listet jedes Plugin im Repo
├── plugins/
│   ├── architects/
│   │   ├── .claude-plugin/plugin.json
│   │   └── agents/architect-review.md
│   └── jira/
│       ├── .claude-plugin/plugin.json
│       └── skills/
│           ├── jira-setup/SKILL.md
│           ├── specify/SKILL.md
│           ├── implement/SKILL.md
│           └── commit/SKILL.md
├── templates/
│   └── plugin/                   # Boilerplate, nicht in marketplace.json
└── README.md
```

**Wichtig zur Benennung:** der Marketplace heißt z. B. `meimberg`. Plugins darin heißen dann *nicht* `meimberg-jira`, sondern einfach `jira` — beim Install schreibt man `/plugin install jira@meimberg`, das `@meimberg` *ist* der Namespace. Doppelung vermeiden.

## Das `marketplace.json`

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "meimberg",
  "description": "...",
  "owner": { "name": "...", "email": "..." },
  "plugins": [
    {
      "name": "jira",
      "description": "...",
      "source": "./plugins/jira",
      "category": "workflow",
      "author": { "name": "..." }
    }
  ]
}
```

Jedes Plugin hat zusätzlich sein eigenes `plugin.json` mit `name`, `version`, `description`, `author`. Beim Hinzufügen eines neuen Plugins: Ordner aus `templates/plugin/` kopieren, anpassen, Eintrag in `marketplace.json` ergänzen, push.

## Installation und Anwendung

Auf der Developer-Maschine, einmalig:

```
/plugin marketplace add meimberg-io/claude-plugins
/plugin install jira@meimberg
/plugin install architects@meimberg
```

Updates später per `/plugin marketplace update meimberg`. Da der Marketplace ein normales Git-Repo ist, ist auch Versionierung, PR-Review und CI-Validation auf neue Plugins anwendbar wie bei jedem anderen Code.

## Wie Skills tatsächlich getriggert werden

Ein Skill ist ein Markdown-File mit YAML-Frontmatter. Beispiel:

```yaml
---
name: commit
description: Stage and commit all changes with a "{Jira-Key}: {Jira-Title}"
  message. Use when the user asks to commit ("commit", "committen", "commit die
  Änderungen"). Resolves the Jira key from message → context → branch → last
  commit. Config from .claude/jira.json.
---
```

Claude Code matcht die `description` gegen das Nutzeranliegen — gut geschriebene Descriptions sind die halbe Miete. Sie müssen sowohl die Trigger-Phrasen enthalten ("commit", "committen", ...) als auch klarmachen, *wofür der Skill nicht da ist*, damit er nicht falsch anspringt.

Alternativ explizit per `/skill <name>`.

## Per-Projekt-Konfiguration als Pattern

Skills, die mit projektabhängigen Werten arbeiten (Jira Project Key, API-Endpoints, Repo-spezifische Konventionen), sollten ihre Konfiguration **nicht in den Skill schreiben** — die wäre dann global. Stattdessen: pro Projekt eine Konfigdatei unter `<projekt>/.claude/<thema>.json`.

Beispiel für unser Jira-Plugin:

```json
{
  "projectKey": "MIVOLVE",
  "cloudId": "86465bd6-...",
  "site": "https://meimberg.atlassian.net",
  "commitPrefix": "VOLVE-",
  "statusNames": { "spec": "...", "ready": "...", "inProgress": "...", "done": "..." }
}
```

Das ist die Brücke zwischen *generischem Firmenskillset* und *konkretem Projekt*. Der Skill ist universal, die Datei macht ihn projektspezifisch.

## Wichtigste Design-Lessons aus der Praxis

**1. Setup-Skills bauen.** Wenn ein Skill eine Konfigdatei voraussetzt, gehört das Anlegen dieser Datei in einen eigenen Skill (`jira-setup`), der den Nutzer interaktiv durch die Konfiguration führt — APIs probet, Defaults vorschlägt, validiert, am Ende schreibt. Sonst muss jeder Workflow-Skill seine eigene Bootstrap-Logik mitschleppen. Diese Duplikation driftet.

**2. Single Source of Truth pro Logik.** Wir hatten anfangs in drei Skills (`specify`, `implement`, `commit`) je 20 Zeilen identische Bootstrap-Logik. Nach Auslagerung in `jira-setup` schrumpft jeder auf einen Dreizeiler: "Wenn `.claude/jira.json` fehlt, run `jira-setup`."

**3. Skills sind Code — verdienen Code-Quality.** Versionierung, PR-Review, Schema-Validation, CI. Ein `templates/`-Verzeichnis mit Plugin-Boilerplate sorgt dafür, dass neue Plugins konsistent aufgebaut sind.

**4. Attribution bei Übernahmen.** Wer Skills/Agents aus anderen Quellen (z. B. aitmpl.com → davila7/claude-code-templates) übernimmt: nicht direkt per `npx` ins User-Verzeichnis ballern. Stattdessen die Quelldatei ins eigene Marketplace-Repo holen, mit Attribution im Footer, und von dort installieren. So bleibt Versionskontrolle erhalten, eigene Anpassungen werden nicht beim nächsten `npx`-Aufruf überschrieben, und Updates aus dem Upstream sind ein bewusster Pull-Vorgang, kein Drift.

**5. Naming-Hygiene.** `<plugin>@<marketplace>` heißt: das `@marketplace` *ist* der Namespace. Plugin-Namen brauchen das Firmen-Präfix nicht zu wiederholen.

## Was als nächstes ins Repo wandert

- **Eigene Patterns:** code-style-Skills pro Stack (React, Go, Python), die die Hausregeln einfließen lassen.
- **Review-Agents:** beyond architecture — security, performance, accessibility, DSGVO.
- **Workflow-Skills:** Sprint-Planning, Standup-Generation, PR-Templating, Release-Notes.
- **CI/Validation:** GitHub Action, die `marketplace.json` gegen das Schema validiert und prüft, dass alle `source`-Pfade existieren.
- **Skill-Authoring-Guide:** ein internes Dokument für Entwickler, das Konventionen für `description`-Felder, Frontmatter, Trigger-Phrasen, Fehlerbehandlung festlegt — damit Skills sich bei neuem Autor nicht anders anfühlen als bei altem.

---

## Fazit

Das Firmen-Skillset gehört ins Versionskontrollsystem wie jeder andere Code. Ein Marketplace-Repo macht es teilbar, versionierbar, reviewbar — und damit zu echtem kollektiven Kapital, das mit jedem Quartal mehr wert wird, statt in den lokalen `~/.claude/`-Ordnern einzelner Entwickler zu verstauben. Wer das früh systematisiert, baut sich einen Vorsprung, den Konkurrenten nicht durch Tooling-Auswahl, sondern nur durch eigene Jahre an Kuration einholen können.

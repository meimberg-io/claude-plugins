# Generalisierung ist binär — keine Zwischenstates

Generalisierungs-Entscheidungen (Helper, Wrapper, zentrale Lib, Architektur-Konvention, Re-Export-Pflicht, Refactoring auf gemeinsame Abstraktion) haben nur zwei legitime Ausgänge:

1. **Voll generalisieren** — Abstraktion bauen *und* überall, wo sinnvoll, konsequent verwenden, mit technischem Schutz gegen Drift (ESLint-`no-restricted-imports`, Type-Guard, Test, Build-Check). Der Sweep über alle bestehenden Call-Sites und der Drift-Schutz sind Teil des Scopes, nicht Folge-Tickets.
2. **Nicht generalisieren** — Problem punktuell lösen, wo es beißt. Keine neue Abstraktion einführen.

**Verboten:** „Wir bauen den Helper, migrieren aber nur den heißen Pfad / die wichtigsten Stellen / Best-Effort." „Neue Files nutzen X, alte dürfen bleiben." „Konvention ohne Lint-Rule." Das sind die Zwischenstates, die nie wieder weggehen.

## Why

Halbe Migrationen produzieren doppelten Schaden:

- **Neue Abstraktion** = zusätzliche kognitive Last („wann nutze ich was?")
- **Plus fortbestehende Inkonsistenz** = das ursprüngliche Konsistenz-Argument für die Generalisierung ist tot, bevor sie sich amortisiert hat.

Über Zeit entsteht so Wildwuchs aus 5–15 Libs/Helpern, die ähnliche Dinge halb machen; nichts ist mehr konsistent. Ohne harten Drift-Schutz (Lint/Test) kehrt der alte Zustand garantiert zurück, weil neue Calls am leichtesten per Copy-Paste vom nächsten Treffer entstehen — und der trifft mit hoher Wahrscheinlichkeit auf einen nicht-migrierten Aufruf.

## How to apply

Sobald ein Vorschlag (Ticket-Spec, eigene Empfehlung, User-Wunsch, Code-Review-Hinweis) eine neue Abstraktion einführt, **vor** der Umsetzung prüfen:

- Ist im Scope: vollständiger Sweep aller bestehenden Call-Sites?
- Ist im Scope: technischer Drift-Schutz (Lint-Rule, Type-Enforcement, CI-Check)?

Falls einer der beiden Punkte fehlt → explizit benennen und entweder

- **in den Scope ziehen** (Spec / Ticket erweitern, Aufwand neu schätzen), oder
- **die Generalisierung selbst streichen** (Helper nicht bauen, Problem punktuell lösen).

Niemals stillschweigend Variante 1 vorschlagen, ohne Sweep+Guard mitzunehmen. Bei Spec-Reviews / Ticket-Reflektionen: „Best-Effort"-Migration, „neue Files nur noch über X", „Konvention ohne Lint" als Red-Flag erkennen und ansprechen, nicht akzeptieren.

## Ausnahme

Kleine Inkonsistenz ist okay, wenn:

- der nicht-migrierte Bereich **explizit deprecated** ist und in absehbarer Zeit verschwindet (Migration läuft, Ticket existiert), oder
- echte **Boundary-Cases** vorliegen, wo das alte Pattern aus externem Grund (3rd-party-Constraint, Lib-Limit) bleiben muss.

In beiden Fällen: dokumentiert, mit Enddatum oder Ticket-Referenz, sichtbar im Code (Kommentar/Marker) — nicht als „machen wir später mal".

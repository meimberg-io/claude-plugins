# templates/

Skeletons for new plugins. Not loaded by Claude Code — `marketplace.json` doesn't reference these.

## Create a new plugin

```bash
cp -R templates/plugin plugins/<name>
```

Then:

1. Edit `plugins/<name>/.claude-plugin/plugin.json` — replace `TODO-plugin-name` and the description.
2. Drop content into the right folder, delete the rest:
   - `agents/` — `*.md` files with frontmatter (`name`, `description`, optional `color`).
   - `skills/<skill>/SKILL.md` — one folder per skill, plus any helper files.
   - `commands/<cmd>.md` — slash commands.
3. Delete `.gitkeep` from any folder you used, delete folders you didn't use.
4. Append an entry to `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "<name>",
     "description": "...",
     "source": "./plugins/<name>",
     "category": "...",
     "author": { "name": "Oliver Meimberg" }
   }
   ```
5. Commit, push, then `/plugin marketplace update meimberg` and `/plugin install <name>@meimberg`.

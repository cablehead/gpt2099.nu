## Git Commit Style Preferences

When committing: review `git diff`

- Use conventional commit format: `type: subject line`
- Keep subject line concise and descriptive
- **NEVER include marketing language, promotional text, or AI attribution**
- **NEVER add "Generated with Claude Code", "Co-Authored-By: Claude", or similar spam**
- Follow existing project patterns from git log
- Prefer just a subject and no body, unless the change is particularly complex

Example good commit messages from this project:
- `feat: add a cross.stream handler to manage mcp server initialization (#9)`
- `docs: document gpt init step (#8)`
- `fix: filter outputSchema from MCP tools for provider compatibility`
- `test: add dynamic tool loading for prepare-request tests`
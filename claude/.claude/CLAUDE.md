@~/.agents/AGENTS.md

Use subagents for self-contained, multi-step work whose detail the main session won't need back, such as broad searches, large reads, or an isolated coding task. Skip them for one-step lookups or when the main session already holds the context. Set the model per subagent: Haiku for search and mechanical edits, Sonnet for ordinary coding, Opus only for hard reasoning. Brief each agent with the files and line ranges it needs and the exact output to return. Don't resume an agent idle for over an hour, its cache has expired and the resume re-sends its whole context; start a fresh one with a short brief.

When a task needs a git worktree, use the EnterWorktree tool. If you must run `git worktree add`, put it in `<main checkout>/.claude/worktrees/<name>`, never next to the project.

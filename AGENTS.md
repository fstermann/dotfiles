# dotfiles

GNU Stow repo. Each top-level dir except `installers/` is a package that mirrors `$HOME`; its files are symlinked there.

- Edits here are live: `~/.zshrc`, `~/.claude/*` and the rest are symlinks into this repo.
- `agents/.agents/` holds shared global instructions and portable skills.
- `claude/.claude/` holds Claude-specific config and skills; `codex/.agents/skills/` holds Codex-specific skills. These are user-level config, not this project's.
- After adding, renaming or deleting a file in a package, run `bash installers/restow.sh`. Stow links files one by one (`--no-folding`), so new files reach `$HOME` and every Claude config dir only after a restow.
- New package: add it to `STOW_PACKAGES` in `installers/lib/packages.sh`, the single source of truth.
- Machine-specific config goes in untracked `~/.zshrc.local`, `~/.gitconfig.local` or `.restow-ignore.local`, never in tracked files.
- Commits use conventional format with a package scope, e.g. `feat(claude): ...`, `fix(installers): ...`.

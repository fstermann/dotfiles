# dotfiles

Personal dotfiles managed with **[GNU Stow](https://www.gnu.org/software/stow/)** — each tool's config lives in its own package directory and gets symlinked into `$HOME`.

![Terminal demo](.demo/demo.gif)

## How it works

The repo lives at `~/.dotfiles/`. Each top-level directory is a *stow package* whose internal structure mirrors `$HOME`. Running `stow <package>` creates symlinks from `$HOME` into the repo:

```
~/.dotfiles/
├── zsh/
│   ├── .zshrc          → symlinked as ~/.zshrc
│   └── .zprofile       → symlinked as ~/.zprofile
├── git/
│   └── .config/git/    → symlinked as ~/.config/git/
├── fzf/
│   └── .config/fzf/    → symlinked as ~/.config/fzf/
├── oh-my-posh/
│   └── .config/zsh/oh-my-posh/
├── claude/
│   └── .claude/        → symlinked as ~/.claude/
├── macos/
│   └── .config/macos/
└── installers/         (not stowed — installer scripts only)
```

---

## Install

Run the install script to clone the repo and set everything up automatically:

```sh
curl -fsSL https://raw.githubusercontent.com/fstermann/dotfiles/main/install.sh | bash
```

Use `--dry-run` to simulate without making changes:

```sh
curl -fsSL https://raw.githubusercontent.com/fstermann/dotfiles/main/install.sh | bash -s -- --dry-run
```

The script will:
1. Clone this repo to `~/.dotfiles/`
2. Install GNU Stow if not already present
3. Back up any existing files that would conflict into `~/.dotfiles-backup/`
4. Stow all packages to create symlinks in `$HOME`
5. Install platform packages (Homebrew, zsh plugins, fzf, oh-my-posh, macOS defaults)
6. Create local config stubs (`.gitconfig.local`, `.zshrc.local`) for machine-specific overrides

---

## The `dotfiles` command

After installation, a `dotfiles` shell function is available with these subcommands:

```sh
dotfiles install   # Run the full installer
dotfiles update    # Pull latest changes, restow packages, upgrade tools
dotfiles doctor    # Health check — verify symlinks, tools, and config
dotfiles <git …>  # Any git command on the dotfiles repo (e.g. dotfiles status)
```

### `dotfiles doctor`

Runs a health check to verify your installation is in good shape:

- **Symlinks** — Checks that all expected symlinks exist and point to the right targets
- **Tools** — Verifies required tools are on `$PATH` (stow, zsh, fzf, bat, rg, oh-my-posh)
- **Config files** — Validates expected configuration files are present
- **Git identity** — Checks that `user.name` and `user.email` are configured

### `dotfiles update`

Pulls the latest changes from the repo and:

- Restows all packages
- Upgrades Homebrew packages (macOS)
- Updates oh-my-posh, fzf, and zsh plugins

---

## Packages

| Package | Contents |
|---|---|
| `zsh` | `.zshrc`, `.zprofile` — shell config, history, plugin loading |
| `git` | `.gitconfig`, `.config/git/` — config + helper scripts (`git pr`, `git remerge`) |
| `fzf` | `.config/fzf/` — fzf config, Monokai color scheme, preview script |
| `oh-my-posh` | `.config/zsh/oh-my-posh/` — Pure prompt theme + fallback prompt |
| `claude` | `.claude/` — Claude editor settings + statusline script |
| `macos` | `.config/macos/` — Terminal.app Monokai Pro theme |

---

## Key features

- **Cross-platform** — Works on macOS and Linux (Debian/Ubuntu)
- **Idempotent** — Safe to re-run install at any time
- **Non-destructive** — Backs up conflicting files before stowing
- **Local overrides** — `~/.zshrc.local` and `~/.gitconfig.local` for machine-specific config (not tracked)
- **Fallback prompt** — Works without oh-my-posh installed (pure Zsh fallback)
- **CI tested** — Dockerfile + GitHub Actions verify installation on fresh Linux

---

## Git aliases

| Alias | Description |
|---|---|
| `git pr <message>` | Create a branch and PR with conventional commit validation |
| `git remerge [target] [source]` | Remerge a branch onto current/target with confirmation |

---

## Manual stow usage

```sh
# Stow all packages (idempotent — safe to re-run)
stow --no-folding -d ~/.dotfiles -t $HOME zsh git fzf oh-my-posh macos claude

# Stow a single package
stow --no-folding -d ~/.dotfiles -t $HOME zsh

# Unstow (remove symlinks for) a package
stow -d ~/.dotfiles -t $HOME -D zsh

# Simulate without making changes
stow --no-folding --simulate -v -d ~/.dotfiles -t $HOME zsh git fzf oh-my-posh macos claude
```

---

## Migrating from the old bare-repo setup

If you previously used the bare git repo approach, run the migration script once:

```sh
bash ~/.dotfiles/migrate.sh
# or, if you still have the old setup:
curl -fsSL https://raw.githubusercontent.com/fstermann/dotfiles/main/migrate.sh | bash
```

This will back up the old bare repo, clone the restructured repo, and use `stow --adopt` to replace existing dotfiles with symlinks without losing any local changes.


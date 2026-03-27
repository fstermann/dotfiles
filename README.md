# dotfiles

Personal dotfiles managed with **[GNU Stow](https://www.gnu.org/software/stow/)** — each tool's config lives in its own package directory and gets symlinked into `$HOME`.

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

The script will:
1. Clone this repo to `~/.dotfiles/`
2. Install GNU Stow if not already present
3. Back up any existing files that would conflict into `~/.dotfiles-backup/`
4. Stow all packages to create symlinks in `$HOME`
5. Install platform packages (Homebrew, zsh plugins, fzf, oh-my-posh, macOS defaults)

---

## Packages

| Package | Contents |
|---|---|
| `zsh` | `.zshrc`, `.zprofile` |
| `git` | `.config/git/` (helper scripts) |
| `fzf` | `.config/fzf/` (fzf config + preview script) |
| `oh-my-posh` | `.config/zsh/oh-my-posh/` (prompt theme) |
| `macos` | `.config/macos/` (Terminal theme) |

---

## Usage

```sh
# Stow all packages (idempotent — safe to re-run)
stow --no-folding -d ~/.dotfiles -t $HOME zsh git fzf oh-my-posh macos

# Stow a single package
stow --no-folding -d ~/.dotfiles -t $HOME zsh

# Unstow (remove symlinks for) a package
stow -d ~/.dotfiles -t $HOME -D zsh

# Simulate without making changes
stow --no-folding --simulate -v -d ~/.dotfiles -t $HOME zsh git fzf oh-my-posh macos
```

Edit files directly in `~/.dotfiles/` and commit with plain `git`:

```sh
cd ~/.dotfiles
git add zsh/.zshrc
git commit -m "chore: update zshrc"
git push
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


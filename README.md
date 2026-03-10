# dotfiles

These are my personal dotfiles managed with a **bare Git repository**; no symlinks, no extra tooling.

## How it works

The home directory (`$HOME`) itself acts as the working tree of a bare Git repo stored at `~/.dotfiles/`. A `dotfiles` alias scopes all Git commands to that repo, so you can track, commit, and push config files directly without cluttering `$HOME` with a `.git` directory.

See the [Arch Linux wiki](https://wiki.archlinux.org/title/Dotfiles#Tracking_dotfiles_directly_with_Git) for a thorough explanation of this approach.

---

## Install

Run the install script to clone the repo and set everything up automatically:

```sh
curl -fsSL https://raw.githubusercontent.com/fstermann/dotfiles/main/install.sh | bash
```

The script will:
1. Clone this repo as a bare repository into `~/.dotfiles/`
2. Back up any existing files that would conflict into `~/.config-backup/`
3. Check out all tracked dotfiles into `$HOME`
4. Configure Git to hide untracked files from `dotfiles status`

---

## Usage

Add the alias to your shell config (the install script handles this reminder):

```sh
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

Then use `dotfiles` exactly like `git`:

```sh
# Check status
dotfiles status

# Track a new file
dotfiles add ~/.zshrc

# Commit and push
dotfiles commit -m "update zshrc"
dotfiles push
```

---

## Manual setup (on a new machine from scratch)

```sh
git clone --bare https://github.com/fstermann/dotfiles.git ~/.dotfiles

alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

mkdir -p ~/.config-backup
dotfiles checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}' | xargs -I{} mv {} ~/.config-backup/{}
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

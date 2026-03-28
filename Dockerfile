FROM ubuntu:24.04

# Minimal deps for a headless install test
# Pre-install everything the installer scripts would apt-get install so that
# the package-list cache (removed for image size) is not needed at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    sudo \
    ca-certificates \
    stow \
    zsh \
    bat \
    ripgrep \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user (stow and dotfiles assume a real $HOME)
RUN useradd -m -s /bin/bash tester \
    && echo "tester ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER tester
WORKDIR /home/tester

# Copy the repo into the image (simulates a fresh clone)
COPY --chown=tester:tester . /home/tester/.dotfiles/

# Make sure git treats the copied repo as safe
RUN git config --global safe.directory /home/tester/.dotfiles

# Run the installer
RUN bash /home/tester/.dotfiles/install.sh

# Verify key tools are on PATH
RUN bash -c '\
    set -e; \
    export PATH="$HOME/.fzf/bin:$HOME/.local/bin:$PATH"; \
    command -v stow; \
    command -v zsh; \
    command -v fzf; \
    command -v bat || command -v batcat; \
    command -v rg; \
    test -L "$HOME/.zshrc"; \
    test -L "$HOME/.zprofile"; \
    echo "All checks passed"'

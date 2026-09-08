# Repository Guidelines

## Project Structure & Module Organization

This repository contains personal macOS and Linux configuration, organized to mirror the home directory. Root dotfiles configure shells (`.zshrc`, `.bash_profile`, `.exports`, `.aliases`), Vim, Git, and tmux. Application settings live under `.config/`, including Neovim, Ghostty, Kitty, i3, and Rofi. Hammerspoon automation lives in `.hammerspoon/init.lua`; themes and other visual assets sit alongside their application configurations.

Third-party components such as `.oh-my-zsh`, `.oh-my-zsh-custom/` plugins, and `.tmux/plugins/tpm` are tracked through Git submodules listed in `.gitmodules`. Keep upstream component changes separate from personal configuration edits.

## Build, Test, and Development Commands

There is no project build step. Run commands from the repository root:

- `bash -n bootstrap.sh dotfiles_status.sh`: check maintenance-script syntax.
- `zsh -n .zshrc`: check Zsh syntax without executing startup code.
- `git diff --check`: detect whitespace errors before committing.
- `./dotfiles_status.sh`: compare repository files with home-directory copies. Inspect individual differences; its pipeline currently prevents the final summary from reliably reflecting changes.
- `./bootstrap.sh --preview`: preview home-directory synchronization. It still runs `git pull` and initializes/updates submodules before the rsync dry run.
- `./bootstrap.sh`: update the repository, preview changes, and request confirmation before copying files home. `--force` skips confirmation.

## Coding Style & Naming Conventions

Follow the surrounding file's indentation; existing scripts mix tabs and spaces, while maintenance scripts use four spaces. Preserve application-standard filenames and directory layout. Quote shell path expansions and check optional commands before invoking them. Load environment and PATH configuration before plugins that depend on it. No repository-wide formatter or lint configuration is provided.

## Testing Guidelines

There is no repository-wide test framework or coverage requirement. Use syntax checks plus focused manual checks in the affected application. For shell startup changes, test a fresh login shell with a minimal inherited PATH; re-sourcing an initialized shell can hide ordering bugs. Verify macOS/Linux differences when changing shared scripts.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects, commonly prefixed by the component, such as `nvim: configure treesitter and lsp for zig`. Keep commits focused. PR descriptions should explain behavior changes, affected platforms, and validation performed; link relevant issues and include screenshots for visual changes.

## Configuration Safety

Review home-directory differences before synchronization and back up affected files. Bootstrap copies files rather than creating symlinks, and currently does not exclude `AGENTS.md`. Keep credentials and machine-specific secrets out of tracked files.

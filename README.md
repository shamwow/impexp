# impexp

Export and import your macOS dev environment onto another machine.

## Usage

```bash
# Export everything (interactive module selection)
./impexp.sh export

# Export everything, auto-accept all prompts
./impexp.sh --yes export

# List available snapshots
./impexp.sh list

# Import from a snapshot directory
./impexp.sh import exports/20260324_152606

# Import from an archive
./impexp.sh import exports/20260324_152606.tar.gz

# Import with auto-accept
./impexp.sh -y import exports/20260324_152606.tar.gz
```

## What gets exported

| Module | What's exported | What's imported |
|---|---|---|
| **shell** | `~/.zshrc`, `~/.zprofile`, `~/.zshenv`, `~/.bashrc`, `~/.bash_profile` — hardcoded home paths are replaced with `$HOME`, bare `source`/`.` commands are guarded with existence checks | Files restored to `~/`, existing files backed up first |
| **git** | `~/.gitconfig`, `~/.gitignore_global` | Files restored; warns to review email/signing key |
| **ohmyzsh** | Custom plugins, themes, and `.zsh` files from `~/.oh-my-zsh/custom/`; records `plugins=` and `ZSH_THEME=` from `.zshrc` | Installs oh-my-zsh if missing, restores custom content |
| **iterm** | iTerm2 preferences plist (converted to XML), DynamicProfiles, Scripts | Restores prefs and profiles; restart iTerm2 after |
| **vscode** | `settings.json`, `keybindings.json`, `snippets/`, installed extensions list | Restores settings, installs extensions via `code --install-extension` |
| **jetbrains** | Per-product `options/`, `keymaps/`, `codestyles/`, `colors/` dirs + plugin list (GoLand, PyCharm, CLion, RustRover, etc.) | Restores to matching product dir; suggests nearest version if exact match not found; prints plugins for manual install |
| **homebrew** | `Brewfile` via `brew bundle dump` (deprecated taps are stripped automatically) | Installs Homebrew if missing, then `brew bundle` to install all formulae and casks |
| **npm** | Global npm packages list, nvm-managed Node versions + default alias | Installs nvm if missing, installs Node versions (skips <v16 on Apple Silicon), installs global packages |
| **golang** | GVM-managed Go versions + default, Go tools from `$GOPATH/bin` with full module paths | Installs GVM if missing, installs Go versions, runs `go install` for each tool |
| **rust** | Rust version, rustup toolchains, `cargo install --list` | Installs Rust via rustup if missing, installs toolchains, installs cargo crates (skips local-path builds) |
| **python** | `uv tool list` (global CLI tools), `uv python list --only-installed` (Python versions) | Installs uv if missing, installs Python versions and tools |

## How it works

- **Export** creates a timestamped snapshot under `exports/` with a `manifest.json` and one subdirectory per module. Optionally creates a `.tar.gz` archive for transfer.
- **Import** reads a snapshot (directory or archive), detects which modules have data, lets you select which to restore, and backs up every existing file before overwriting.
- **Backups** are created as `<file>.impexp-backup.<timestamp>` next to the original.


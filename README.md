# vim-claude-complete

A Vim plugin that brings Claude Code's `@file` and `/command` completion experience into Vim when editing prompts with `ctrl+e`.

## Features

- **`@` fuzzy file search** — type `@` followed by any part of a filename to recursively search the project and insert the path
- **`/` slash-command palette** — type `/` at the start of a line or after a space to browse built-in Claude Code commands and installed skills
- **Tab to accept** — press `Tab` to confirm a completion, `ctrl+n`/`ctrl+p` to navigate
- **Zero side effects** — only activates when Vim is opened via the `vim-claude` wrapper script (`CLAUDE_EDITOR=1`); has no effect in regular Vim usage

## Requirements

- Vim 8.0+ (uses lambda syntax `{_, v -> ...}`)
- [Claude Code](https://github.com/anthropics/claude-code) or [Ducc](https://ducc.baidu.com) CLI

## Installation

### Vundle

Add to your `.vimrc`:

```vim
Plugin 'your-github-username/vim-claude-complete'
```

Then run `:PluginInstall`.

### vim-plug

```vim
Plug 'your-github-username/vim-claude-complete'
```

Then run `:PlugInstall`.

### Manual

Copy `plugin/claude_complete.vim` to `~/.vim/plugin/`.

## Setup

The plugin activates only when the environment variable `CLAUDE_EDITOR=1` is set. Create a wrapper script so Claude Code opens Vim through it:

```bash
# ~/.local/bin/vim-claude
#!/bin/bash
export CLAUDE_EDITOR=1
exec vim -c "cd $(pwd)" "$@"
```

```bash
chmod +x ~/.local/bin/vim-claude
```

Then set it as your editor in `~/.zshrc` (or `~/.bashrc`):

```bash
export EDITOR='vim-claude'
```

Now pressing `ctrl+e` inside Claude Code / Ducc opens the prompt in Vim with this plugin active.

## Usage

### `@` — File completion

Type `@` anywhere in the buffer to open a fuzzy file picker scoped to the current project directory.

```
Fix the bug in @src/co       →  shows src/components/Foo.tsx, src/core/bar.go, …
```

- Results are sorted: exact filename prefix > path substring > fuzzy match
- Common build artefact directories (`node_modules`, `.git`, `dist`, …) are excluded
- File list is cached for 30 seconds

### `/` — Slash-command palette

Type `/` at the start of a line or after whitespace to open the command palette.

```
/comp    →  /compact   (Compact conversation to save context)
/mem     →  /memory    (View and edit memory files)
/action  →  /actionbook  [skill]
```

- Shows all built-in Claude Code commands
- Auto-discovers installed skills from `~/.claude/skills/`
- Skill list refreshes every 60 seconds
- `/` in the middle of a word (e.g. `src/foo`) is inserted literally — no interference

### Keybindings (insert mode, active only inside the completion menu)

| Key | Action |
|-----|--------|
| `Tab` | Accept selected completion |
| `ctrl+n` | Select next item |
| `ctrl+p` | Select previous item |
| `Esc` | Close menu, keep typed text |

## Skill discovery

The plugin looks for installed skills in:

- `~/.claude/skills/<skill-name>/` — standard Claude Code / Ducc install location

Each subdirectory name becomes a `/command` entry in the palette. Namespaced skills like `somto-dev-toolkit:commit` appear as `/somto-dev-toolkit:commit` with the short alias `commit` shown in the abbreviation column.

## License

MIT

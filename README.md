# zsh-worktree

A Zsh plugin for managing Git worktrees across multiple repositories. Quickly switch between worktrees, create new ones, and clean up stale worktrees with deleted branches.

## Features

- 🔀 **Switch or create worktrees** with a single command
- 📋 **List worktrees** for any repository
- 🗑️ **Remove worktrees** safely (auto-switches if you're in it)
- 🧹 **Cleanup orphaned worktrees** whose branches have been deleted
- 🎯 **Multi-repo support** with `--repo` flag
- ⚙️ **Configurable** paths, defaults, and post-creation instructions

## Installation

### Oh My Zsh (recommended)

```bash
# Clone to your custom plugins directory
git clone https://github.com/eric-gish-zocdoc/zsh-worktree ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/worktree

# Add to plugins in ~/.zshrc
plugins=(git worktree)

# Reload
source ~/.zshrc
```

### Manual Installation

```bash
# Clone anywhere
git clone https://github.com/eric-gish-zocdoc/zsh-worktree ~/.zsh/plugins/worktree

# Add to ~/.zshrc
source ~/.zsh/plugins/worktree/worktree.plugin.zsh

# Reload
source ~/.zshrc
```

### One-liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/ericgish/zsh-worktree/main/install.sh | bash
```

## Usage

```bash
# Show help and list current worktrees
worktree

# List all worktrees
worktree ls
worktree list

# Switch to a worktree (or create if it doesn't exist)
worktree my-feature-branch

# Remove a worktree
worktree rm my-feature-branch
worktree remove my-feature-branch

# Clean up worktrees for deleted branches
worktree cleanup

# Show current configuration
worktree config

# Work with a different repo
worktree --repo=other-repo ls
worktree --repo=other-repo my-branch
```

## Configuration

Set these environment variables in your `~/.zshrc` **before** the plugins line:

```zsh
# Where your main repositories live
export WORKTREE_REPOS_ROOT="$HOME/code"

# Where worktrees are created (default: $WORKTREE_REPOS_ROOT/worktrees)
export WORKTREE_BASE_DIR="$HOME/code/worktrees"

# Default repository name when --repo isn't specified
export WORKTREE_DEFAULT_REPO="my-repo"
```

### Directory Structure

With the default configuration, your directory structure would look like:

```
~/code/
├── my-repo/                    # Main repo (WORKTREE_REPOS_ROOT/WORKTREE_DEFAULT_REPO)
│   └── .git/
├── other-repo/                 # Another repo
│   └── .git/
└── worktrees/                  # WORKTREE_BASE_DIR
    ├── my-repo/
    │   ├── feature-a/          # worktree my-feature-a
    │   └── feature-b/          # worktree my-feature-b
    └── other-repo/
        └── bugfix/             # worktree --repo=other-repo bugfix
```

## Post-Creation Instructions

After creating a worktree, the plugin can display setup instructions. There are three ways to configure this:

### Option 1: Default Message

```zsh
export WORKTREE_POST_CREATE_MSG="npm install\nnpm run build"
```

### Option 2: Per-Repo Messages

```zsh
typeset -gA WORKTREE_POST_CREATE_MSGS
WORKTREE_POST_CREATE_MSGS[frontend-repo]="yarn install
yarn build:ts"
WORKTREE_POST_CREATE_MSGS[backend-repo]="dotnet restore
dotnet build"
```

### Option 3: Custom Hook Function (most flexible)

```zsh
worktree_post_create_hook() {
  local repo="$1"
  local branch="$2"
  local path="$3"
  
  echo "Next steps:"
  case "$repo" in
    frontend-repo)
      echo "  1. yarn install"
      echo "  2. yarn build:ts"
      echo "  3. cursor ."
      ;;
    backend-repo)
      echo "  1. dotnet restore"
      echo "  2. dotnet build"
      ;;
    *)
      echo "  Set up your environment for $repo"
      ;;
  esac
}
```

Priority: hook function > per-repo message > default message

## Commands Reference

| Command | Description |
|---------|-------------|
| `worktree` | Show help and list worktrees |
| `worktree ls` / `list` | List all worktrees |
| `worktree <branch>` | Switch to worktree (creates if needed) |
| `worktree rm <branch>` / `remove` | Remove a worktree |
| `worktree cleanup` | Remove worktrees with deleted branches |
| `worktree config` | Show current configuration |
| `worktree --repo=<name> <cmd>` | Run command for a different repo |

## How It Works

### Creating Worktrees

When you run `worktree my-branch`:

1. If the worktree exists, it switches to it (`cd`)
2. If not, it checks if the branch exists (local or remote)
3. Prompts to create the worktree
4. Creates from existing branch or creates new branch from master
5. Switches to the new worktree
6. Shows post-creation instructions

### Cleanup

The `cleanup` command:

1. Prunes stale worktree references
2. Fetches with `--prune` to sync remote branch info
3. Finds worktrees whose branches no longer exist
4. Prompts before removing orphaned worktrees

## Requirements

- Zsh 5.0+
- Git 2.5+ (for worktree support)
- Oh My Zsh (optional, but recommended)

## License

MIT

## Contributing

Issues and PRs welcome! This started as a personal tool, so there may be edge cases to handle.


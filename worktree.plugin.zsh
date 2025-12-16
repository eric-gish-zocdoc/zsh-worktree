# Worktree Manager Plugin for Oh My Zsh
# 
# Usage: worktree [--repo=<repo>] <command> [args]
#
# Commands:
#   ls, list              - List all worktrees
#   rm, remove <branch>   - Remove a worktree
#   cleanup               - Remove worktrees for deleted branches
#   config                - Show current configuration
#   <branch-name>         - Switch to or create a worktree
#
# Configuration (set these in .zshrc before plugins are loaded):
#   WORKTREE_REPOS_ROOT   - Root directory containing repos (default: $HOME/code)
#   WORKTREE_BASE_DIR     - Directory for worktrees (default: $WORKTREE_REPOS_ROOT/worktrees)
#   WORKTREE_DEFAULT_REPO - Default repo name (default: my-repo)
#
# Post-creation instructions (choose one):
#   WORKTREE_POST_CREATE_MSG        - Default message shown after creating a worktree
#   WORKTREE_POST_CREATE_MSGS       - Associative array for per-repo messages
#                                     e.g., WORKTREE_POST_CREATE_MSGS[my-repo]="npm install"
#   worktree_post_create_hook()     - Custom function called with (repo, branch, path)
#                                     Define this function for complete control

# Set defaults if not configured
: ${WORKTREE_REPOS_ROOT:="$HOME/code"}
: ${WORKTREE_BASE_DIR:="$WORKTREE_REPOS_ROOT/worktrees"}
: ${WORKTREE_DEFAULT_REPO:="my-repo"}
: ${WORKTREE_POST_CREATE_MSG:="Run your setup commands here"}

# Initialize the associative array if not already defined
if ! (( ${+WORKTREE_POST_CREATE_MSGS} )); then
  typeset -gA WORKTREE_POST_CREATE_MSGS
fi

worktree() {
  local repo="$WORKTREE_DEFAULT_REPO"
  local args=()
  
  # Parse arguments - extract --repo if present
  for arg in "$@"; do
    case "$arg" in
      --repo=*)
        repo="${arg#--repo=}"
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done
  
  local MAIN_REPO="$WORKTREE_REPOS_ROOT/$repo"
  local WORKTREE_BASE="$WORKTREE_BASE_DIR/$repo"
  
  # Verify main repo exists
  if [[ ! -d "$MAIN_REPO/.git" ]]; then
    echo "Error: Repository not found at $MAIN_REPO"
    return 1
  fi
  
  local command="${args[1]}"
  
  # Handle subcommands
  case "$command" in
    ls|list)
      _worktree_ls "$MAIN_REPO"
      ;;
    rm|remove)
      _worktree_rm "$MAIN_REPO" "$WORKTREE_BASE" "${args[2]}"
      ;;
    cleanup)
      _worktree_cleanup "$MAIN_REPO" "$WORKTREE_BASE"
      ;;
    config)
      _worktree_config "$repo" "$MAIN_REPO" "$WORKTREE_BASE"
      ;;
    "")
      echo "Usage: worktree [--repo=<repo>] <command> [args]"
      echo ""
      echo "Commands:"
      echo "  ls, list              - List all worktrees"
      echo "  rm, remove <branch>   - Remove a worktree"
      echo "  cleanup               - Remove worktrees for deleted branches"
      echo "  config                - Show current configuration"
      echo "  <branch-name>         - Switch to or create a worktree"
      echo ""
      echo "Options:"
      echo "  --repo=<repo>         - Specify repository (default: $WORKTREE_DEFAULT_REPO)"
      echo ""
      echo "Current worktrees for $repo:"
      git -C "$MAIN_REPO" worktree list
      return 1
      ;;
    *)
      # Assume it's a branch name - switch or create worktree
      _worktree_switch "$repo" "$MAIN_REPO" "$WORKTREE_BASE" "$command"
      ;;
  esac
}

# List all worktrees
_worktree_ls() {
  local MAIN_REPO="$1"
  git -C "$MAIN_REPO" worktree list
}

# Show current configuration
_worktree_config() {
  local repo="$1"
  local MAIN_REPO="$2"
  local WORKTREE_BASE="$3"
  
  echo "Worktree Plugin Configuration"
  echo "=============================="
  echo ""
  echo "Path Configuration:"
  echo "  WORKTREE_REPOS_ROOT   = $WORKTREE_REPOS_ROOT"
  echo "  WORKTREE_BASE_DIR     = $WORKTREE_BASE_DIR"
  echo "  WORKTREE_DEFAULT_REPO = $WORKTREE_DEFAULT_REPO"
  echo ""
  echo "Current Repo: $repo"
  echo "  Main repo path:     $MAIN_REPO"
  echo "  Worktree base path: $WORKTREE_BASE"
  echo ""
  if [[ -d "$MAIN_REPO/.git" ]]; then
    echo "  ✅ Main repo exists"
  else
    echo "  ❌ Main repo not found"
  fi
  if [[ -d "$WORKTREE_BASE" ]]; then
    echo "  ✅ Worktree directory exists"
  else
    echo "  ⚠️  Worktree directory does not exist (will be created on first worktree)"
  fi
  
  echo ""
  echo "Post-Creation Instructions:"
  if typeset -f worktree_post_create_hook > /dev/null; then
    echo "  Using: worktree_post_create_hook() function"
  elif [[ -n "${WORKTREE_POST_CREATE_MSGS[$repo]}" ]]; then
    echo "  Using: WORKTREE_POST_CREATE_MSGS[$repo]"
    echo "  Message:"
    echo "${WORKTREE_POST_CREATE_MSGS[$repo]}" | while IFS= read -r line; do
      echo "    $line"
    done
  else
    echo "  Using: WORKTREE_POST_CREATE_MSG (default)"
    echo "  Message:"
    echo -e "$WORKTREE_POST_CREATE_MSG" | while IFS= read -r line; do
      echo "    $line"
    done
  fi
  
  # Show all configured repo-specific messages
  if [[ ${#WORKTREE_POST_CREATE_MSGS[@]} -gt 0 ]]; then
    echo ""
    echo "Repo-Specific Messages Configured:"
    for key in "${(@k)WORKTREE_POST_CREATE_MSGS}"; do
      echo "  $key"
    done
  fi
}

# Remove a worktree
_worktree_rm() {
  local MAIN_REPO="$1"
  local WORKTREE_BASE="$2"
  local branch="$3"
  
  if [[ -z "$branch" ]]; then
    echo "Usage: worktree rm <branch-name>"
    return 1
  fi
  
  local worktree_path="$WORKTREE_BASE/$branch"
  
  if [[ ! -d "$worktree_path" ]]; then
    echo "Worktree doesn't exist: $worktree_path"
    return 1
  fi
  
  # If we're in the worktree we're trying to remove, switch out first
  if [[ "$(pwd)" == "$worktree_path"* ]]; then
    echo "Currently in this worktree, switching to main repo first..."
    cd "$MAIN_REPO"
  fi
  
  echo "Removing worktree: $worktree_path"
  git -C "$MAIN_REPO" worktree remove "$worktree_path"
}

# Cleanup worktrees for deleted branches
_worktree_cleanup() {
  local MAIN_REPO="$1"
  local WORKTREE_BASE="$2"
  local deleted_count=0
  
  echo "Checking worktrees for deleted branches..."
  echo ""
  
  # First, prune any stale worktree references
  git -C "$MAIN_REPO" worktree prune
  
  # Fetch latest from origin to ensure we have current branch info
  echo "Fetching latest from origin..."
  git -C "$MAIN_REPO" fetch --prune origin 2>/dev/null
  echo ""
  
  # Get list of worktrees (skip the main repo itself)
  local worktrees_to_remove=()
  
  while IFS= read -r line; do
    local wt_path=$(echo "$line" | awk '{print $1}')
    local wt_branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p')
    
    # Skip the main repo
    if [[ "$wt_path" == "$MAIN_REPO" ]]; then
      continue
    fi
    
    # Skip detached HEAD
    if [[ -z "$wt_branch" ]] || [[ "$wt_branch" == "detached HEAD" ]]; then
      continue
    fi
    
    # Check if branch exists locally
    if ! git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/$wt_branch" 2>/dev/null; then
      # Branch doesn't exist locally, check if it exists on origin
      if ! git -C "$MAIN_REPO" show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null; then
        echo "Found orphaned worktree: $wt_branch"
        echo "  Path: $wt_path"
        worktrees_to_remove+=("$wt_path|$wt_branch")
      fi
    fi
  done < <(git -C "$MAIN_REPO" worktree list)
  
  if [[ ${#worktrees_to_remove[@]} -eq 0 ]]; then
    echo "✅ No orphaned worktrees found. All worktrees have valid branches."
    return 0
  fi
  
  echo ""
  echo "Found ${#worktrees_to_remove[@]} orphaned worktree(s)."
  read "response?Remove all orphaned worktrees? [y/N] "
  
  if [[ "$response" =~ ^[Yy]$ ]]; then
    for item in "${worktrees_to_remove[@]}"; do
      local wt_path="${item%|*}"
      local wt_branch="${item#*|}"
      
      # If we're in a worktree we're trying to remove, switch out first
      if [[ "$(pwd)" == "$wt_path"* ]]; then
        echo "Currently in $wt_branch, switching to main repo first..."
        cd "$MAIN_REPO"
      fi
      
      echo "Removing worktree: $wt_branch ($wt_path)"
      if git -C "$MAIN_REPO" worktree remove --force "$wt_path" 2>/dev/null; then
        ((deleted_count++))
      else
        echo "  ⚠️  Failed to remove worktree, trying to force cleanup..."
        rm -rf "$wt_path"
        git -C "$MAIN_REPO" worktree prune
        ((deleted_count++))
      fi
    done
    
    echo ""
    echo "✅ Removed $deleted_count orphaned worktree(s)."
  else
    echo "Cancelled."
    return 1
  fi
}

# Switch to or create a worktree
_worktree_switch() {
  local repo="$1"
  local MAIN_REPO="$2"
  local WORKTREE_BASE="$3"
  local branch="$4"
  
  local worktree_path="$WORKTREE_BASE/$branch"
  
  # Check if worktree already exists
  if [[ -d "$worktree_path" ]]; then
    echo "Switching to worktree: $worktree_path"
    cd "$worktree_path"
    return 0
  fi
  
  # Worktree doesn't exist - prompt to create
  echo "Worktree for branch '$branch' doesn't exist at:"
  echo "  $worktree_path"
  echo ""
  
  # Check if branch exists locally or remotely
  local branch_exists=false
  if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    branch_exists=true
    echo "Branch '$branch' exists locally."
  elif git -C "$MAIN_REPO" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
    branch_exists=true
    echo "Branch '$branch' exists on origin."
  else
    echo "Branch '$branch' does not exist (will create new branch from master)."
  fi
  
  echo ""
  read "response?Create worktree? [y/N] "
  
  if [[ "$response" =~ ^[Yy]$ ]]; then
    # Create worktrees directory if it doesn't exist
    mkdir -p "$WORKTREE_BASE"
    
    if [[ "$branch_exists" == true ]]; then
      echo "Creating worktree for existing branch '$branch'..."
      git -C "$MAIN_REPO" worktree add "$worktree_path" "$branch"
    else
      echo "Creating worktree with new branch '$branch' from master..."
      git -C "$MAIN_REPO" worktree add -b "$branch" "$worktree_path" master
    fi
    
    if [[ $? -eq 0 ]]; then
      echo ""
      echo "Worktree created! Switching to: $worktree_path"
      cd "$worktree_path"
      echo ""
      _worktree_show_post_create_msg "$repo" "$branch" "$worktree_path"
    else
      echo "Error creating worktree."
      return 1
    fi
  else
    echo "Cancelled."
    return 1
  fi
}

# Show post-creation message/run hook
_worktree_show_post_create_msg() {
  local repo="$1"
  local branch="$2"
  local worktree_path="$3"
  
  # Option 1: Custom hook function (highest priority)
  if typeset -f worktree_post_create_hook > /dev/null; then
    worktree_post_create_hook "$repo" "$branch" "$worktree_path"
    return
  fi
  
  # Option 2: Per-repo message from associative array
  if [[ -n "${WORKTREE_POST_CREATE_MSGS[$repo]}" ]]; then
    echo "Don't forget to run:"
    echo "${WORKTREE_POST_CREATE_MSGS[$repo]}" | while IFS= read -r line; do
      echo "  $line"
    done
    return
  fi
  
  # Option 3: Default message
  if [[ -n "$WORKTREE_POST_CREATE_MSG" ]]; then
    echo "Don't forget to run:"
    echo -e "$WORKTREE_POST_CREATE_MSG" | while IFS= read -r line; do
      echo "  $line"
    done
  fi
}


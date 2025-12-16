#!/bin/bash
#
# zsh-worktree installer
# Installs the worktree plugin for Oh My Zsh or standalone zsh
#

set -e

# If stdin is not a terminal (e.g., piped from curl), try to reconnect to /dev/tty
if [ ! -t 0 ]; then
  if (exec </dev/tty) 2>/dev/null; then
    exec </dev/tty
  fi
fi

REPO_URL="https://github.com/eric-gish-zocdoc/zsh-worktree"
PLUGIN_NAME="worktree"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "$1"; }
print_prompt() { echo -e "${BLUE}$1${NC}"; }

# Read user input - works with curl | bash by reading from /dev/tty if available
read_input() {
  if [ -t 0 ]; then
    # stdin is a terminal, read normally
    read "$@"
  elif (exec </dev/tty) 2>/dev/null; then
    # stdin is piped but /dev/tty works
    read "$@" </dev/tty
  else
    # No tty available, read from stdin (may get empty input)
    read "$@"
  fi
}

# Detect installation method
detect_install_type() {
  if [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins" ]]; then
    echo "omz"
  elif [[ -d "$HOME/.zsh" ]]; then
    echo "standalone"
  else
    echo "none"
  fi
}

# Prompt for configuration
configure_plugin() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "         Plugin Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Default values
  local default_repos_root="$HOME/Zocdoc"
  local default_worktrees_dir="$HOME/Zocdoc/worktrees"
  local default_repo=""
  
  # Repos root
  print_prompt "Where are your Git repositories located?"
  echo "  (This is the parent directory containing your repos)"
  read_input -p "  [$default_repos_root]: " repos_root
  repos_root="${repos_root:-$default_repos_root}"
  # Expand ~ to $HOME
  repos_root="${repos_root/#\~/$HOME}"
  echo ""
  
  # Worktrees directory
  local suggested_worktrees="$repos_root/worktrees"
  print_prompt "Where should worktrees be created?"
  read_input -p "  [$suggested_worktrees]: " worktrees_dir
  worktrees_dir="${worktrees_dir:-$suggested_worktrees}"
  worktrees_dir="${worktrees_dir/#\~/$HOME}"
  echo ""
  
  # Default repo
  print_prompt "What is your default/primary repository name?"
  echo "  (The repo you use most often, e.g., 'frontend-monorepo')"
  read_input -p "  [no default]: " default_repo
  echo ""
  
  # Show summary
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "         Configuration Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Repos root:     $repos_root"
  echo "  Worktrees dir:  $worktrees_dir"
  if [[ -n "$default_repo" ]]; then
    echo "  Default repo:   $default_repo"
  else
    echo "  Default repo:   (none)"
  fi
  echo ""
  
  read_input -p "Add this configuration to ~/.zshrc? [Y/n]: " add_config
  add_config="${add_config:-Y}"
  
  if [[ "$add_config" =~ ^[Yy]$ ]]; then
    add_config_to_zshrc "$repos_root" "$worktrees_dir" "$default_repo"
  else
    echo ""
    print_info "Add these lines to your ~/.zshrc manually (before the plugins line):"
    echo ""
    echo "  export WORKTREE_REPOS_ROOT=\"$repos_root\""
    echo "  export WORKTREE_BASE_DIR=\"$worktrees_dir\""
    if [[ -n "$default_repo" ]]; then
      echo "  export WORKTREE_DEFAULT_REPO=\"$default_repo\""
    fi
    echo ""
  fi
}

# Add configuration to .zshrc
add_config_to_zshrc() {
  local repos_root="$1"
  local worktrees_dir="$2"
  local default_repo="$3"
  local zshrc="$HOME/.zshrc"
  
  # Convert $HOME back to ~ for cleaner output in .zshrc
  local repos_root_display="${repos_root/$HOME/\$HOME}"
  local worktrees_dir_display="${worktrees_dir/$HOME/\$HOME}"
  
  # Check if configuration already exists
  if grep -q "WORKTREE_REPOS_ROOT" "$zshrc" 2>/dev/null; then
    print_warning "Worktree configuration already exists in ~/.zshrc"
    read_input -p "Replace existing configuration? [y/N]: " replace
    if [[ ! "$replace" =~ ^[Yy]$ ]]; then
      print_info "Skipping configuration update."
      return
    fi
    # Remove existing config
    sed -i.bak '/# Worktree plugin configuration/,/^$/d' "$zshrc"
    sed -i.bak '/WORKTREE_REPOS_ROOT/d' "$zshrc"
    sed -i.bak '/WORKTREE_BASE_DIR/d' "$zshrc"
    sed -i.bak '/WORKTREE_DEFAULT_REPO/d' "$zshrc"
  fi
  
  # Build the config block
  local config_block="
# Worktree plugin configuration
export WORKTREE_REPOS_ROOT=\"$repos_root_display\"
export WORKTREE_BASE_DIR=\"$worktrees_dir_display\""
  
  if [[ -n "$default_repo" ]]; then
    config_block="$config_block
export WORKTREE_DEFAULT_REPO=\"$default_repo\""
  fi
  config_block="$config_block
"
  
  # Find the best place to insert (before plugins= line, or before source oh-my-zsh)
  if grep -q "^plugins=" "$zshrc"; then
    # Insert before plugins= line
    local line_num=$(grep -n "^plugins=" "$zshrc" | head -1 | cut -d: -f1)
    
    # Create temp file with insertion
    head -n $((line_num - 1)) "$zshrc" > "$zshrc.tmp"
    echo "$config_block" >> "$zshrc.tmp"
    tail -n +$line_num "$zshrc" >> "$zshrc.tmp"
    mv "$zshrc.tmp" "$zshrc"
  else
    # Append to end
    echo "$config_block" >> "$zshrc"
  fi
  
  print_success "Configuration added to ~/.zshrc"
}

# Install for Oh My Zsh
install_omz() {
  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$PLUGIN_NAME"
  
  print_info "Installing for Oh My Zsh..."
  
  if [[ -d "$plugin_dir" ]]; then
    print_warning "Plugin directory already exists. Updating..."
    rm -rf "$plugin_dir"
  fi
  
  # Clone or copy the plugin
  if [[ -f "$(dirname "$0")/worktree.plugin.zsh" ]]; then
    # Installing from local clone
    mkdir -p "$plugin_dir"
    cp "$(dirname "$0")/worktree.plugin.zsh" "$plugin_dir/"
  else
    # Clone from remote
    git clone --depth 1 "$REPO_URL" "$plugin_dir"
  fi
  
  print_success "Plugin installed to $plugin_dir"
  
  # Check if worktree is in plugins list
  if ! grep -q "worktree" "$HOME/.zshrc" 2>/dev/null || ! grep "^plugins=" "$HOME/.zshrc" | grep -q "worktree"; then
    echo ""
    print_warning "Don't forget to add 'worktree' to your plugins in ~/.zshrc:"
    echo ""
    echo "  plugins=(git worktree)"
  fi
}

# Install standalone (without Oh My Zsh)
install_standalone() {
  local plugin_dir="$HOME/.zsh/plugins/$PLUGIN_NAME"
  
  print_info "Installing standalone..."
  
  mkdir -p "$plugin_dir"
  
  if [[ -f "$(dirname "$0")/worktree.plugin.zsh" ]]; then
    cp "$(dirname "$0")/worktree.plugin.zsh" "$plugin_dir/"
  else
    git clone --depth 1 "$REPO_URL" "$plugin_dir"
  fi
  
  print_success "Plugin installed to $plugin_dir"
  
  # Check if source line exists
  if ! grep -q "worktree.plugin.zsh" "$HOME/.zshrc" 2>/dev/null; then
    echo ""
    print_warning "Don't forget to add this to your ~/.zshrc:"
    echo ""
    echo "  source ~/.zsh/plugins/worktree/worktree.plugin.zsh"
  fi
}

# Uninstall
uninstall() {
  local omz_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$PLUGIN_NAME"
  local standalone_dir="$HOME/.zsh/plugins/$PLUGIN_NAME"
  
  print_info "Uninstalling zsh-worktree..."
  
  if [[ -d "$omz_dir" ]]; then
    rm -rf "$omz_dir"
    print_success "Removed $omz_dir"
    print_info "Remember to remove 'worktree' from plugins in ~/.zshrc"
  fi
  
  if [[ -d "$standalone_dir" ]]; then
    rm -rf "$standalone_dir"
    print_success "Removed $standalone_dir"
    print_info "Remember to remove the source line from ~/.zshrc"
  fi
  
  # Optionally remove config from .zshrc
  if grep -q "WORKTREE_REPOS_ROOT" "$HOME/.zshrc" 2>/dev/null; then
    read_input -p "Remove worktree configuration from ~/.zshrc? [y/N]: " remove_config
    if [[ "$remove_config" =~ ^[Yy]$ ]]; then
      sed -i.bak '/# Worktree plugin configuration/,/^$/d' "$HOME/.zshrc"
      sed -i.bak '/WORKTREE_REPOS_ROOT/d' "$HOME/.zshrc"
      sed -i.bak '/WORKTREE_BASE_DIR/d' "$HOME/.zshrc"
      sed -i.bak '/WORKTREE_DEFAULT_REPO/d' "$HOME/.zshrc"
      print_success "Configuration removed from ~/.zshrc"
    fi
  fi
}

# Main
main() {
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║     zsh-worktree Plugin Installer      ║"
  echo "╚════════════════════════════════════════╝"
  echo ""
  
  case "${1:-install}" in
    install)
      local install_type=$(detect_install_type)
      
      case "$install_type" in
        omz)
          install_omz
          ;;
        standalone)
          install_standalone
          ;;
        none)
          print_info "No existing zsh plugin directory found."
          echo ""
          echo "Choose installation type:"
          echo "  1) Oh My Zsh (recommended)"
          echo "  2) Standalone"
          echo ""
          read_input -p "Enter choice [1/2]: " choice
          
          case "$choice" in
            1)
              mkdir -p "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
              install_omz
              ;;
            2)
              install_standalone
              ;;
            *)
              print_error "Invalid choice"
              exit 1
              ;;
          esac
          ;;
      esac
      
      # Configure the plugin
      configure_plugin
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      print_success "Installation complete!"
      echo ""
      print_info "Run this to apply changes:"
      echo "  source ~/.zshrc"
      echo ""
      print_info "Then try:"
      echo "  worktree config"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      ;;
    uninstall)
      uninstall
      ;;
    *)
      echo "Usage: $0 [install|uninstall]"
      exit 1
      ;;
  esac
}

main "$@"

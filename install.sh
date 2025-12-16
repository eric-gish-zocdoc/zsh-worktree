#!/bin/bash
#
# zsh-worktree installer
# Installs the worktree plugin for Oh My Zsh or standalone zsh
#

set -e

REPO_URL="https://github.com/ericgish/zsh-worktree"
PLUGIN_NAME="worktree"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "$1"; }

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

# Install for Oh My Zsh
install_omz() {
  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$PLUGIN_NAME"
  
  print_info "Installing for Oh My Zsh..."
  
  if [[ -d "$plugin_dir" ]]; then
    print_warning "Plugin directory already exists. Updating..."
    rm -rf "$plugin_dir"
  fi
  
  # Clone or copy the plugin
  if [[ -d "$(dirname "$0")/.git" ]] || [[ -f "$(dirname "$0")/worktree.plugin.zsh" ]]; then
    # Installing from local clone
    mkdir -p "$plugin_dir"
    cp "$(dirname "$0")/worktree.plugin.zsh" "$plugin_dir/"
  else
    # Clone from remote
    git clone --depth 1 "$REPO_URL" "$plugin_dir"
  fi
  
  print_success "Plugin installed to $plugin_dir"
  echo ""
  print_info "Add 'worktree' to your plugins in ~/.zshrc:"
  echo ""
  echo "  plugins=(git worktree)"
  echo ""
}

# Install standalone (without Oh My Zsh)
install_standalone() {
  local plugin_dir="$HOME/.zsh/plugins/$PLUGIN_NAME"
  
  print_info "Installing standalone..."
  
  mkdir -p "$plugin_dir"
  
  if [[ -d "$(dirname "$0")/.git" ]] || [[ -f "$(dirname "$0")/worktree.plugin.zsh" ]]; then
    cp "$(dirname "$0")/worktree.plugin.zsh" "$plugin_dir/"
  else
    git clone --depth 1 "$REPO_URL" "$plugin_dir"
  fi
  
  print_success "Plugin installed to $plugin_dir"
  echo ""
  print_info "Add this to your ~/.zshrc:"
  echo ""
  echo "  source ~/.zsh/plugins/worktree/worktree.plugin.zsh"
  echo ""
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
          read "choice?Enter choice [1/2]: "
          
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
      
      echo ""
      print_info "After updating ~/.zshrc, run: source ~/.zshrc"
      echo ""
      print_info "Configure the plugin by setting these before the plugins line:"
      echo ""
      echo "  export WORKTREE_REPOS_ROOT=\"\$HOME/code\""
      echo "  export WORKTREE_DEFAULT_REPO=\"my-repo\""
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


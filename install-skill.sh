#!/bin/bash
# install-skill.sh - Install Claude skills from this repository
#
# Usage:
#   ./install-skill.sh <skill-name>              Install a skill to Claude Code
#   ./install-skill.sh <skill-name> --target desktop  Create ZIP for Claude Desktop
#   ./install-skill.sh --list                    List available skills
#   ./install-skill.sh --all                     Install all skills
#   ./install-skill.sh <skill-name> --uninstall  Uninstall a skill

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIRS=("claude-skills" "claude-code-skills")
CODE_SKILLS_DIR="$HOME/.claude/skills"
DESKTOP_DOWNLOADS="$HOME/Downloads"

# Default options
TARGET="code"
METHOD="symlink"
UNINSTALL=false
LIST_ONLY=false
ALL_SKILLS=false
FORCE=false
SKILL_PATTERN=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_error() { echo -e "${RED}Error: $1${NC}" >&2; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info() { echo -e "${BLUE}$1${NC}"; }

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SKILL_PATTERN]

Install Claude skills from this repository to Claude Code or Claude Desktop.

Arguments:
  SKILL_PATTERN       Skill name or wildcard pattern (e.g., "travel-*")

Options:
  --target TARGET     Installation target: code (default), desktop, or both
  --method METHOD     Installation method for Claude Code: symlink (default) or copy
  --uninstall         Remove the skill instead of installing
  --all               Install all available skills
  --list              List available skills
  --force             Overwrite existing installations without prompting
  -h, --help          Show this help message

Examples:
  $(basename "$0") travel-assistant                    Install travel-assistant to Claude Code
  $(basename "$0") travel-assistant --target desktop   Create ZIP for Claude Desktop
  $(basename "$0") travel-assistant --target both      Install to both targets
  $(basename "$0") "travel-*"                          Install skills matching pattern
  $(basename "$0") --all                               Install all skills
  $(basename "$0") --list                              List available skills
  $(basename "$0") travel-assistant --uninstall        Uninstall a skill
  $(basename "$0") travel-assistant --method copy      Copy files instead of symlink
EOF
}

# Find all available skills
list_skills() {
    local skills=()
    for dir in "${SKILL_DIRS[@]}"; do
        local full_path="$SCRIPT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            for skill_dir in "$full_path"/*/; do
                if [[ -f "${skill_dir}SKILL.md" ]]; then
                    local skill_name=$(basename "$skill_dir")
                    local description=$(grep -A1 '^description:' "${skill_dir}SKILL.md" 2>/dev/null | head -1 | sed 's/^description: *"//' | sed 's/"$//' | cut -c1-60)
                    skills+=("$skill_name|$dir|$description")
                fi
            done
        fi
    done
    printf '%s\n' "${skills[@]}"
}

# Display skills in a formatted table
display_skills() {
    local skills_output
    skills_output=$(list_skills)

    if [[ -z "$skills_output" ]]; then
        print_warning "No skills found in repository."
        return 1
    fi

    echo ""
    print_info "Available Skills:"
    echo ""
    printf "  %-25s %-20s %s\n" "SKILL" "DIRECTORY" "DESCRIPTION"
    printf "  %-25s %-20s %s\n" "-----" "---------" "-----------"

    while IFS= read -r skill_info; do
        IFS='|' read -r name dir desc <<< "$skill_info"
        printf "  %-25s %-20s %s\n" "$name" "$dir" "$desc..."
    done <<< "$skills_output"
    echo ""
}

# Match skills by name or wildcard pattern
match_skills() {
    local pattern="$1"
    local matched=()

    while IFS= read -r skill_info; do
        local skill_name=$(echo "$skill_info" | cut -d'|' -f1)
        # shellcheck disable=SC2053
        if [[ "$skill_name" == $pattern ]]; then
            matched+=("$skill_info")
        fi
    done < <(list_skills)

    printf '%s\n' "${matched[@]}"
}

# Get skill directory path
get_skill_path() {
    local skill_name="$1"
    for dir in "${SKILL_DIRS[@]}"; do
        local full_path="$SCRIPT_DIR/$dir/$skill_name"
        if [[ -d "$full_path" && -f "$full_path/SKILL.md" ]]; then
            echo "$full_path"
            return 0
        fi
    done
    return 1
}

# Prompt user for confirmation
confirm() {
    local message="$1"
    if [[ "$FORCE" == true ]]; then
        return 0
    fi

    read -r -p "$message [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Install skill to Claude Code
install_to_code() {
    local skill_name="$1"
    local method="$2"

    local skill_path
    skill_path=$(get_skill_path "$skill_name") || {
        print_error "Skill '$skill_name' not found."
        return 1
    }

    # Create skills directory if needed
    if [[ ! -d "$CODE_SKILLS_DIR" ]]; then
        print_info "Creating skills directory: $CODE_SKILLS_DIR"
        mkdir -p "$CODE_SKILLS_DIR"
    fi

    local target_path="$CODE_SKILLS_DIR/$skill_name"

    # Check if already installed (use -L for symlinks, -e for regular files/dirs)
    if [[ -L "$target_path" || -e "$target_path" ]]; then
        if [[ -L "$target_path" ]]; then
            local current_link=$(readlink "$target_path")
            if [[ "$current_link" == "$skill_path" ]]; then
                print_warning "Skill '$skill_name' is already installed (symlinked to same location)."
                return 0
            fi
            print_warning "Skill '$skill_name' is already installed as symlink to: $current_link"
        else
            print_warning "Skill '$skill_name' is already installed at: $target_path"
        fi

        if ! confirm "Do you want to overwrite it?"; then
            print_info "Skipping '$skill_name'."
            return 0
        fi
        rm -rf "$target_path"
    fi

    # Install using specified method
    if [[ "$method" == "symlink" ]]; then
        ln -s "$skill_path" "$target_path"
        print_success "Installed '$skill_name' to Claude Code (symlink)"
        print_info "  $target_path -> $skill_path"
    else
        cp -r "$skill_path" "$target_path"
        print_success "Installed '$skill_name' to Claude Code (copy)"
        print_info "  $target_path"
    fi
}

# Install skill to Claude Desktop (create ZIP)
install_to_desktop() {
    local skill_name="$1"

    local skill_path
    skill_path=$(get_skill_path "$skill_name") || {
        print_error "Skill '$skill_name' not found."
        return 1
    }

    # Create Downloads directory if needed (unlikely but just in case)
    if [[ ! -d "$DESKTOP_DOWNLOADS" ]]; then
        mkdir -p "$DESKTOP_DOWNLOADS"
    fi

    local zip_path="$DESKTOP_DOWNLOADS/${skill_name}.zip"

    # Check if ZIP already exists
    if [[ -f "$zip_path" ]]; then
        print_warning "ZIP file already exists: $zip_path"
        if ! confirm "Do you want to overwrite it?"; then
            print_info "Skipping '$skill_name'."
            return 0
        fi
        rm -f "$zip_path"
    fi

    # Create ZIP file
    local parent_dir=$(dirname "$skill_path")
    (cd "$parent_dir" && zip -r "$zip_path" "$skill_name" -x "*.DS_Store" -x "*__MACOSX*") > /dev/null

    print_success "Created ZIP for Claude Desktop: $zip_path"
    echo ""
    print_info "To install in Claude Desktop:"
    echo "  1. Open Claude Desktop"
    echo "  2. Go to Settings > Capabilities > Skills"
    echo "  3. Click 'Upload skill'"
    echo "  4. Select: $zip_path"
    echo ""
}

# Uninstall skill from Claude Code
uninstall_skill() {
    local skill_name="$1"

    local target_path="$CODE_SKILLS_DIR/$skill_name"

    if [[ ! -e "$target_path" ]]; then
        print_warning "Skill '$skill_name' is not installed in Claude Code."
        return 0
    fi

    if ! confirm "Are you sure you want to uninstall '$skill_name'?"; then
        print_info "Cancelled."
        return 0
    fi

    rm -rf "$target_path"
    print_success "Uninstalled '$skill_name' from Claude Code."
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                TARGET="$2"
                if [[ ! "$TARGET" =~ ^(code|desktop|both)$ ]]; then
                    print_error "Invalid target: $TARGET. Must be 'code', 'desktop', or 'both'."
                    exit 1
                fi
                shift 2
                ;;
            --method)
                METHOD="$2"
                if [[ ! "$METHOD" =~ ^(symlink|copy)$ ]]; then
                    print_error "Invalid method: $METHOD. Must be 'symlink' or 'copy'."
                    exit 1
                fi
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --list)
                LIST_ONLY=true
                shift
                ;;
            --all)
                ALL_SKILLS=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                SKILL_PATTERN="$1"
                shift
                ;;
        esac
    done
}

# Main execution
main() {
    parse_args "$@"

    # Handle --list
    if [[ "$LIST_ONLY" == true ]]; then
        display_skills
        exit 0
    fi

    # Determine which skills to process
    local skills_to_process=()

    if [[ "$ALL_SKILLS" == true ]]; then
        while IFS= read -r skill_info; do
            [[ -n "$skill_info" ]] && skills_to_process+=("$(echo "$skill_info" | cut -d'|' -f1)")
        done < <(list_skills)
    elif [[ -n "$SKILL_PATTERN" ]]; then
        while IFS= read -r skill_info; do
            [[ -n "$skill_info" ]] && skills_to_process+=("$(echo "$skill_info" | cut -d'|' -f1)")
        done < <(match_skills "$SKILL_PATTERN")
    else
        print_error "No skill specified. Use --list to see available skills."
        echo ""
        usage
        exit 1
    fi

    # Check if any skills matched
    if [[ ${#skills_to_process[@]} -eq 0 ]]; then
        print_error "No skills found matching '$SKILL_PATTERN'."
        echo ""
        display_skills
        exit 1
    fi

    # Process each skill
    for skill_name in "${skills_to_process[@]}"; do
        echo ""
        print_info "Processing: $skill_name"

        if [[ "$UNINSTALL" == true ]]; then
            uninstall_skill "$skill_name"
        else
            case "$TARGET" in
                code)
                    install_to_code "$skill_name" "$METHOD"
                    ;;
                desktop)
                    install_to_desktop "$skill_name"
                    ;;
                both)
                    install_to_code "$skill_name" "$METHOD"
                    install_to_desktop "$skill_name"
                    ;;
            esac
        fi
    done

    echo ""
    print_success "Done!"
}

main "$@"

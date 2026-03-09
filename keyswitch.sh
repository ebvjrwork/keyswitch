#!/bin/bash

#############################################################################
# keyswitch - SSH Key Management Tool
#
# A self-installing tool to manage multiple SSH keys for different work
# contexts. Easily create, switch, and manage SSH keys for GitHub, GitLab,
# and other SSH services.
#
# Installation: curl -fsSL <url_to_this_script> | sh
# Usage: keyswitch <command> [options]
#############################################################################

set -e  # Exit on error

# Version
VERSION="1.0.0"

# Configuration
SSH_DIR="${HOME}/.ssh"
CONFIG_FILE="${SSH_DIR}/.keyswitch_config"
KEY_PREFIX="keyswitch_"
BACKUP_DIR="${HOME}/keyswitch_backups"

#############################################################################
# Cross-Platform Compatibility Utilities
#############################################################################

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        *)          echo "unknown";;
    esac
}

OS_TYPE=$(detect_os)

# Get current timestamp (POSIX-compatible)
get_timestamp() {
    date +%s
}

# Get formatted date (POSIX-compatible)
get_formatted_date() {
    date "+%Y-%m-%d %H:%M:%S"
}

#############################################################################
# Color and Output Utilities
#############################################################################

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Print functions
print_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo -e "${BOLD}${CYAN}$1${NC}"
}

#############################################################################
# Self-Installation Function
#############################################################################

install_keyswitch() {
    print_header "Installing keyswitch..."

    # Determine installation directory
    local install_dir=""

    if [ -w "/usr/local/bin" ]; then
        install_dir="/usr/local/bin"
    elif [ -d "${HOME}/.local/bin" ] || mkdir -p "${HOME}/.local/bin" 2>/dev/null; then
        install_dir="${HOME}/.local/bin"
    else
        print_error "Cannot find writable installation directory"
        echo "Please create ~/.local/bin and add it to your PATH, or run with sudo"
        exit 1
    fi

    # Copy this script to installation directory
    local target="${install_dir}/keyswitch"

    # Create temporary file with script content
    cat > "${target}.tmp" << 'SCRIPT_END'
#!/bin/bash
SCRIPT_CONTENT_PLACEHOLDER
SCRIPT_END

    # Replace placeholder with actual script (read from stdin or self)
    if [ ! -t 0 ]; then
        # Being piped, read from stdin
        cat > "${target}"
        chmod +x "${target}"
    else
        # Direct execution, copy self
        cp "$0" "${target}"
        chmod +x "${target}"
    fi

    # Create .ssh directory if it doesn't exist
    if [ ! -d "${SSH_DIR}" ]; then
        mkdir -p "${SSH_DIR}"
        chmod 700 "${SSH_DIR}"
        print_success "Created ${SSH_DIR} directory"
    fi

    # Create config file if it doesn't exist
    if [ ! -f "${CONFIG_FILE}" ]; then
        touch "${CONFIG_FILE}"
        chmod 600 "${CONFIG_FILE}"
    fi

    print_success "keyswitch installed to ${target}"

    # Check if install_dir is in PATH
    if [[ ":${PATH}:" != *":${install_dir}:"* ]]; then
        print_warning "${install_dir} is not in your PATH"
        echo "Add it to your PATH by adding this line to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$PATH:${install_dir}\""
    fi

    print_info "Run 'keyswitch --help' to get started"
    exit 0
}

# Check if being piped (installation mode)
if [ ! -t 0 ]; then
    install_keyswitch
fi

#############################################################################
# Configuration Management
#############################################################################

# Read value from config
config_get() {
    local key="$1"
    local name="$2"

    if [ ! -f "${CONFIG_FILE}" ]; then
        return 1
    fi

    grep "^${name}\.${key}=" "${CONFIG_FILE}" 2>/dev/null | cut -d= -f2-
}

# Set value in config
config_set() {
    local key="$1"
    local name="$2"
    local value="$3"

    local config_key="${name}.${key}"

    if [ ! -f "${CONFIG_FILE}" ]; then
        touch "${CONFIG_FILE}"
        chmod 600 "${CONFIG_FILE}"
    fi

    # Remove old value if exists
    if grep -q "^${config_key}=" "${CONFIG_FILE}" 2>/dev/null; then
        # Use a temp file for cross-platform compatibility
        grep -v "^${config_key}=" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
    fi

    # Add new value
    echo "${config_key}=${value}" >> "${CONFIG_FILE}"
}

# Get all key names from config
config_list_keys() {
    if [ ! -f "${CONFIG_FILE}" ]; then
        return
    fi

    grep "^[^#]" "${CONFIG_FILE}" 2>/dev/null | cut -d. -f1 | sort -u
}

#############################################################################
# SSH Key Management
#############################################################################

# Get full path for a key name
get_key_path() {
    local name="$1"
    echo "${SSH_DIR}/${KEY_PREFIX}${name}"
}

# Check if a key exists
key_exists() {
    local name="$1"
    local key_path=$(get_key_path "$name")
    [ -f "${key_path}" ]
}

# Validate key name
validate_key_name() {
    local name="$1"

    if [ -z "$name" ]; then
        print_error "Key name cannot be empty"
        return 1
    fi

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Key name can only contain letters, numbers, hyphens, and underscores"
        return 1
    fi

    return 0
}

# Check if ssh-agent is running
check_ssh_agent() {
    if [ -z "$SSH_AUTH_SOCK" ]; then
        print_error "ssh-agent is not running"
        echo ""
        echo "Start ssh-agent with:"
        echo "  eval \$(ssh-agent)"
        echo ""
        echo "Or add this to your ~/.bashrc or ~/.zshrc to start automatically:"
        echo "  if [ -z \"\$SSH_AUTH_SOCK\" ]; then"
        echo "    eval \$(ssh-agent) > /dev/null"
        echo "  fi"
        return 1
    fi
    return 0
}

# Get list of loaded keys from ssh-agent
get_loaded_keys() {
    if ! check_ssh_agent >/dev/null 2>&1; then
        return
    fi
    ssh-add -l 2>/dev/null | awk '{print $3}' || true
}

# Check if a key is loaded in ssh-agent
is_key_loaded() {
    local key_path="$1"
    local loaded_keys=$(get_loaded_keys)
    echo "$loaded_keys" | grep -q "^${key_path}$"
}

#############################################################################
# Command: create
#############################################################################

cmd_create() {
    local name="$1"

    if [ -z "$name" ]; then
        print_error "Usage: keyswitch create <name>"
        exit 1
    fi

    validate_key_name "$name" || exit 1

    local key_path=$(get_key_path "$name")

    if key_exists "$name"; then
        print_error "Key '${name}' already exists"
        exit 1
    fi

    # Ask for key type
    echo "Select key type:"
    echo "  1) ed25519 (recommended - modern, secure, fast)"
    echo "  2) rsa (legacy compatibility)"
    read -p "Enter choice [1]: " key_type_choice
    key_type_choice=${key_type_choice:-1}

    local key_type=""
    local key_bits=""

    case "$key_type_choice" in
        1)
            key_type="ed25519"
            ;;
        2)
            key_type="rsa"
            key_bits="4096"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Ask for email/comment (optional)
    read -p "Enter email/comment (optional): " comment

    # Generate key
    print_info "Generating ${key_type} key..."

    local ssh_keygen_args="-t ${key_type} -f ${key_path}"

    if [ -n "$key_bits" ]; then
        ssh_keygen_args="${ssh_keygen_args} -b ${key_bits}"
    fi

    if [ -n "$comment" ]; then
        ssh_keygen_args="${ssh_keygen_args} -C ${comment}"
    fi

    # Run ssh-keygen (this will prompt for passphrase)
    echo ""
    echo "Enter passphrase (leave empty for no passphrase):"
    if ssh-keygen $ssh_keygen_args; then
        # Set proper permissions
        chmod 600 "${key_path}"
        chmod 644 "${key_path}.pub"

        # Store metadata
        config_set "type" "$name" "$key_type"
        config_set "created" "$name" "$(get_formatted_date)"
        config_set "fingerprint" "$name" "$(ssh-keygen -lf ${key_path} | awk '{print $2}')"

        print_success "Key '${name}' created successfully"
        echo ""
        print_info "Private key: ${key_path}"
        print_info "Public key: ${key_path}.pub"
        echo ""
        echo "Next steps:"
        echo "  1. View public key: keyswitch view ${name}"
        echo "  2. Load key: keyswitch set ${name}"
    else
        print_error "Failed to create key"
        exit 1
    fi
}

#############################################################################
# Command: set
#############################################################################

cmd_set() {
    local name="$1"

    if [ -z "$name" ]; then
        print_error "Usage: keyswitch set <name>"
        exit 1
    fi

    if ! key_exists "$name"; then
        print_error "Key '${name}' does not exist"
        echo "Create it first with: keyswitch create ${name}"
        exit 1
    fi

    if ! check_ssh_agent; then
        exit 1
    fi

    local key_path=$(get_key_path "$name")

    # Add key to ssh-agent
    if ssh-add "${key_path}" 2>/dev/null; then
        # Update last used timestamp
        config_set "last_used" "$name" "$(get_formatted_date)"

        local fingerprint=$(config_get "fingerprint" "$name")
        print_success "Key '${name}' loaded into ssh-agent"
        if [ -n "$fingerprint" ]; then
            print_info "Fingerprint: ${fingerprint}"
        fi

        echo ""
        echo "Key is now active for SSH connections."
        echo "Test it with: keyswitch test ${name}"
    else
        print_error "Failed to load key into ssh-agent"
        exit 1
    fi
}

#############################################################################
# Command: view
#############################################################################

cmd_view() {
    local name="$1"

    if [ -z "$name" ]; then
        print_error "Usage: keyswitch view <name>"
        exit 1
    fi

    if ! key_exists "$name"; then
        print_error "Key '${name}' does not exist"
        exit 1
    fi

    local key_path=$(get_key_path "$name")
    local pub_key_path="${key_path}.pub"

    print_header "SSH Key: ${name}"
    echo ""

    # Show metadata
    local key_type=$(config_get "type" "$name")
    local created=$(config_get "created" "$name")
    local last_used=$(config_get "last_used" "$name")
    local fingerprint=$(config_get "fingerprint" "$name")

    if [ -n "$key_type" ]; then
        echo "Type: ${key_type}"
    fi
    if [ -n "$created" ]; then
        echo "Created: ${created}"
    fi
    if [ -n "$last_used" ]; then
        echo "Last Used: ${last_used}"
    fi
    if [ -n "$fingerprint" ]; then
        echo "Fingerprint: ${fingerprint}"
    fi

    echo ""
    print_header "Public Key:"
    echo ""
    cat "${pub_key_path}"
    echo ""
    echo ""
    print_info "Copy the public key above and add it to:"
    echo "  • GitHub: https://github.com/settings/keys"
    echo "  • GitLab: https://gitlab.com/-/profile/keys"
    echo "  • Bitbucket: https://bitbucket.org/account/settings/ssh-keys/"
    echo "  • Or any other SSH service"
}

#############################################################################
# Command: list
#############################################################################

cmd_list() {
    print_header "Managed SSH Keys"
    echo ""

    local keys=($(config_list_keys))

    if [ ${#keys[@]} -eq 0 ]; then
        print_info "No keys found. Create one with: keyswitch create <name>"
        return
    fi

    local loaded_keys=$(get_loaded_keys)

    printf "%-20s %-10s %-20s %-20s %s\n" "NAME" "TYPE" "CREATED" "LAST USED" "STATUS"
    echo "--------------------------------------------------------------------------------"

    for name in "${keys[@]}"; do
        local key_path=$(get_key_path "$name")
        local key_type=$(config_get "type" "$name")
        local created=$(config_get "created" "$name")
        local last_used=$(config_get "last_used" "$name")

        # Check if loaded
        local status=""
        if echo "$loaded_keys" | grep -q "^${key_path}$"; then
            status="${GREEN}● loaded${NC}"
        else
            status="○ not loaded"
        fi

        printf "%-20s %-10s %-20s %-20s %b\n" \
            "$name" \
            "${key_type:-unknown}" \
            "${created:-unknown}" \
            "${last_used:-never}" \
            "$status"
    done
}

#############################################################################
# Command: test
#############################################################################

cmd_test() {
    local name="$1"
    local host="${2:-git@github.com}"

    if [ -z "$name" ]; then
        print_error "Usage: keyswitch test <name> [host]"
        echo "Default host: git@github.com"
        exit 1
    fi

    if ! key_exists "$name"; then
        print_error "Key '${name}' does not exist"
        exit 1
    fi

    local key_path=$(get_key_path "$name")

    print_info "Testing SSH connection to ${host}..."
    echo ""

    # Test SSH connection with specific key
    ssh -T -o "IdentitiesOnly=yes" -o "IdentityFile=${key_path}" "$host" 2>&1 || true

    echo ""
    print_info "Connection test completed"
}

#############################################################################
# Command: backup
#############################################################################

cmd_backup() {
    # Create backup directory if it doesn't exist
    mkdir -p "${BACKUP_DIR}"

    local timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_file="${BACKUP_DIR}/ssh_backup_${timestamp}.tar.gz"

    print_info "Creating backup of ${SSH_DIR}..."

    if tar czf "${backup_file}" -C "${HOME}" ".ssh" 2>/dev/null; then
        print_success "Backup created: ${backup_file}"

        local size=$(du -h "${backup_file}" | cut -f1)
        print_info "Backup size: ${size}"
    else
        print_error "Failed to create backup"
        exit 1
    fi
}

#############################################################################
# Command: restore
#############################################################################

cmd_restore() {
    if [ ! -d "${BACKUP_DIR}" ]; then
        print_error "No backups found in ${BACKUP_DIR}"
        exit 1
    fi

    local backups=($(ls -t "${BACKUP_DIR}"/ssh_backup_*.tar.gz 2>/dev/null || true))

    if [ ${#backups[@]} -eq 0 ]; then
        print_error "No backups found"
        exit 1
    fi

    print_header "Available Backups:"
    echo ""

    local i=1
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local timestamp=$(echo "$filename" | sed 's/ssh_backup_\(.*\)\.tar\.gz/\1/')
        echo "  ${i}) ${timestamp} (${size})"
        i=$((i + 1))
    done

    echo ""
    read -p "Select backup to restore [1-${#backups[@]}] or 'q' to cancel: " choice

    if [ "$choice" = "q" ]; then
        echo "Cancelled"
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        print_error "Invalid choice"
        exit 1
    fi

    local selected_backup="${backups[$((choice - 1))]}"

    echo ""
    print_warning "This will replace your current ~/.ssh directory"
    read -p "Are you sure? [y/N]: " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled"
        exit 0
    fi

    # Create a safety backup first
    local safety_backup="${BACKUP_DIR}/ssh_backup_before_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar czf "${safety_backup}" -C "${HOME}" ".ssh" 2>/dev/null
    print_info "Created safety backup: ${safety_backup}"

    # Restore
    if tar xzf "${selected_backup}" -C "${HOME}" 2>/dev/null; then
        print_success "Backup restored successfully"
        print_warning "Please restart ssh-agent and reload your keys"
    else
        print_error "Failed to restore backup"
        exit 1
    fi
}

#############################################################################
# Command: install
#############################################################################

cmd_install() {
    install_keyswitch
}

#############################################################################
# Help Documentation
#############################################################################

show_help() {
    cat << EOF
${BOLD}keyswitch${NC} v${VERSION} - SSH Key Management Tool

${BOLD}USAGE:${NC}
    keyswitch <command> [options]

${BOLD}COMMANDS:${NC}
    ${BOLD}create <name>${NC}
        Create a new SSH key with the given name.
        Prompts for key type (ed25519 or rsa) and optional passphrase.

    ${BOLD}set <name>${NC}
        Load the specified SSH key into ssh-agent for the current session.
        The key will be used for SSH connections.

    ${BOLD}view <name>${NC}
        Display the public key and metadata for the specified key.
        Use this to copy the public key to GitHub/GitLab/etc.

    ${BOLD}list${NC}
        Show all managed SSH keys with their metadata and status.
        Indicates which keys are currently loaded in ssh-agent.

    ${BOLD}test <name> [host]${NC}
        Test SSH connection using the specified key.
        Default host: git@github.com

    ${BOLD}backup${NC}
        Create a timestamped backup of your entire ~/.ssh directory.
        Backups are stored in ~/keyswitch_backups/

    ${BOLD}restore${NC}
        Restore ~/.ssh directory from a previous backup.
        Displays a list of available backups to choose from.

    ${BOLD}install${NC}
        Install keyswitch to your system (same as piped installation).

    ${BOLD}--help, -h${NC}
        Show this help message.

    ${BOLD}--version, -v${NC}
        Show version information.

${BOLD}EXAMPLES:${NC}
    # Create a new SSH key for work
    keyswitch create work

    # View the public key (to add to GitHub)
    keyswitch view work

    # Load the work key into ssh-agent
    keyswitch set work

    # List all managed keys
    keyswitch list

    # Test connection to GitHub
    keyswitch test work git@github.com

    # Create a backup
    keyswitch backup

${BOLD}INSTALLATION:${NC}
    # Install via curl (recommended)
    curl -fsSL <url_to_script> | sh

    # Or download and run
    chmod +x keyswitch.sh
    ./keyswitch.sh install

${BOLD}NOTES:${NC}
    • Keys are stored in ~/.ssh/ with prefix 'keyswitch_'
    • Requires ssh-agent to be running for 'set' command
    • Supports both Linux and macOS
    • Configuration stored in ~/.ssh/.keyswitch_config

${BOLD}MORE INFO:${NC}
    GitHub: <repository_url>
    Report issues: <issues_url>
EOF
}

show_version() {
    echo "keyswitch v${VERSION}"
}

#############################################################################
# Main Command Router
#############################################################################

main() {
    local command="${1:-}"

    case "$command" in
        create)
            shift
            cmd_create "$@"
            ;;
        set)
            shift
            cmd_set "$@"
            ;;
        view)
            shift
            cmd_view "$@"
            ;;
        list)
            cmd_list
            ;;
        test)
            shift
            cmd_test "$@"
            ;;
        backup)
            cmd_backup
            ;;
        restore)
            cmd_restore
            ;;
        install)
            install_keyswitch
            ;;
        --help|-h|help)
            show_help
            ;;
        --version|-v)
            show_version
            ;;
        "")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Run 'keyswitch --help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

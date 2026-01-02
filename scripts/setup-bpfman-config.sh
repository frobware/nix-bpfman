#!/usr/bin/env bash

# setup-bpfman-config.sh
#
# Configure bpfman for development and testing.
# Creates /etc/bpfman/bpfman.toml with signature verification disabled
# for faster testing and development.

set -euo pipefail

: "${DRY_RUN:=0}"  # Set to 1 for dry-run mode
: "${FORCE:=0}"    # Set to 1 to overwrite existing config

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

info() {
    echo -e "${BLUE}[CONFIG]${NC} $*"
}

# Configuration template
BPFMAN_CONFIG='[signing]
allow_unsigned = true
verify_enabled = false

[logging]
# Uncomment and adjust log level if needed
# level = "debug"

# [database]
# # Uncomment to use a different database path
# path = "/var/lib/bpfman/bpfman.db"
'

# Default paths
BPFMAN_DIR="/etc/bpfman"
BPFMAN_CONFIG_FILE="${BPFMAN_DIR}/bpfman.toml"

create_config() {
    local config_content="$1"
    local config_file="$2"
    local config_dir
    config_dir=$(dirname "$config_file")

    if [[ "${DRY_RUN}" == "1" ]]; then
        echo "[DRY RUN] Would create directory: $config_dir"
        echo "[DRY RUN] Would create config file: $config_file"
        echo "[DRY RUN] Config content:"
        echo "$config_content"
        return 0
    fi

    # Create directory if it doesn't exist
    if [[ ! -d "$config_dir" ]]; then
        log "Creating directory: $config_dir"
        sudo mkdir -p "$config_dir"
    fi

    # Write config file
    log "Creating bpfman configuration: $config_file"
    sudo tee "$config_file" > /dev/null << EOF
$config_content
EOF

    # Set appropriate permissions
    sudo chmod 644 "$config_file"
    sudo chown root:root "$config_file"

    info "Configuration created successfully!"
}

show_current_config() {
    if [[ -f "$BPFMAN_CONFIG_FILE" ]]; then
        info "Current bpfman configuration:"
        echo "----------------------------------------"
        sudo cat "$BPFMAN_CONFIG_FILE"
        echo "----------------------------------------"
    else
        info "No existing bpfman configuration found"
    fi
}

main() {
    log "Setting up bpfman configuration..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        warn "Running in DRY RUN mode - no changes will be made"
    fi

    # Check if running as root or with sudo for actual changes
    if [[ $EUID -ne 0 ]] && [[ "${DRY_RUN}" != "1" ]]; then
        error "This script requires root privileges to write to /etc/bpfman/"
        error "Run with sudo or set DRY_RUN=1 to see what would be done"
        exit 1
    fi

    # Check if config already exists
    if [[ -f "$BPFMAN_CONFIG_FILE" ]] && [[ "${FORCE}" != "1" ]]; then
        warn "Configuration file already exists: $BPFMAN_CONFIG_FILE"
        show_current_config
        warn "Use --force to overwrite, or --show to display current config"
        exit 1
    fi

    # Create the configuration
    create_config "$BPFMAN_CONFIG" "$BPFMAN_CONFIG_FILE"

    if [[ "${DRY_RUN}" != "1" ]]; then
        show_current_config

        log "Configuration complete!"
        info "Benefits of this configuration:"
        info "  • Faster testing (no signature verification)"
        info "  • Allows unsigned BPF bytecode"
        info "  • Suitable for development environments"
        info ""
        info "To revert, simply delete: $BPFMAN_CONFIG_FILE"
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [options]

Set up bpfman configuration for development and testing.
Creates /etc/bpfman/bpfman.toml with signature verification disabled.

Options:
  --show            Show current configuration and exit
  --force           Overwrite existing configuration
  --dry-run         Show what would be done without making changes
  --help, -h        Show this help message

Environment variables:
  DRY_RUN=1         Enable dry-run mode
  FORCE=1           Enable force mode

Examples:
  sudo $0                    # Create configuration
  $0 --show                  # Show current config
  $0 --dry-run               # Preview changes
  sudo $0 --force            # Overwrite existing config

Configuration details:
  The configuration disables cosign/sigstore signature verification
  for faster development and testing. This allows:

  • Loading unsigned BPF bytecode
  • Faster program loading (no network verification)
  • Offline development workflow

  This is recommended for development but NOT for production.
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --show)
            show_current_config
            exit 0
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"

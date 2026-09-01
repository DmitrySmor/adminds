#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../src/lib/colors.sh"
source "$SCRIPT_DIR/../src/lib/log.sh"

log_header "Test header"
log_info "This is an info message"
log_step "This is a step"
log_success "This is a success message"
log_warning "This is a warning message"
log_error "This is an error message"

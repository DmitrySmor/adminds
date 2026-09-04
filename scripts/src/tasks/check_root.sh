#!/usr/bin/env bash

set -euo pipefail

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "Скрипт должен быть запущен от имени root"
        exit 1
    fi

    log_success "Права root подтверждены"
}

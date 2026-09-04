#!/usr/bin/env bash

set -euo pipefail

install_nala() {
    log_step "Установка Nala..."

    apt-get install -y nala

    if ! command -v nala >/dev/null 2>&1; then
        log_error "Nala не установлен"
        exit 1
    fi

    log_success "Nala установлен"
}

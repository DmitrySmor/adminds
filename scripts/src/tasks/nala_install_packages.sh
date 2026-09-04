#!/usr/bin/env bash

set -euo pipefail

nala_install_packages() {
    if ! command -v nala >/dev/null 2>&1; then
        log_step "Установка Nala..."
        apt-get install -y nala

        if ! command -v nala >/dev/null 2>&1; then
            log_error "Nala не установлен"
            exit 1
        fi

        log_success "Nala установлен"
    fi

    nala install -y "$@"

    log_success "Пакеты установлены"
}

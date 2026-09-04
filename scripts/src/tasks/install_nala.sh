#!/usr/bin/env bash

set -euo pipefail

install_nala() {
    log_step "Установка Nala..."

    apt-get install -y nala

    log_success "Nala установлен"
}

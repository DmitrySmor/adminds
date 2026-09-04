#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Установка пакетов через Nala
# ============================
# Проверяет наличие Nala и устанавливает его через APT,
# если Nala ещё не установлен.
#
# После установки Nala устанавливает переданные пакеты.
#
# Например: nala_install_packages curl git vim
nala_install_packages() {
    if ! command -v nala >/dev/null 2>&1; then
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

#!/usr/bin/env bash

set -euo pipefail

# Проверка операционной системы

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Файл /etc/os-release не найден"
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "$ID" != "debian" ]]; then
        log_error "Поддерживается только Debian"
        exit 1
    fi

    if [[ "$VERSION_ID" != "13" ]]; then
        log_error "Поддерживается только Debian 13, обнаружена версия $VERSION_ID"
        exit 1
    fi

    log_success "Операционная система: Debian $VERSION_ID"
}

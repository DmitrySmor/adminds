#!/usr/bin/env bash

set -euo pipefail

update_system() {
    log_step "Обновление списка пакетов..."
    apt-get update

    log_success "Список пакетов обновлён"
}

#!/usr/bin/env bash

set -euo pipefail

update_system() {
    apt-get update
    log_success "Список пакетов обновлён"
}

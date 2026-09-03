#!/usr/bin/env bash

set -euo pipefail

log_step "Обновление списка пакетов..."
apt-get update

log_step "Обновление установленных пакетов..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

log_success "Система обновлена"

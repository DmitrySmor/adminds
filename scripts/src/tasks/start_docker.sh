#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Запуск Docker
# ============================
# Включает Docker при загрузке системы
# и запускает сервис Docker.
#
# После запуска выводится состояние сервиса.
start_docker() {
    systemctl enable --now docker
    systemctl status docker --no-pager | head -5

    log_success "Docker запущен"
}

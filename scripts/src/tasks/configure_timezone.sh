#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Настройка часового пояса
# ============================
# Устанавливает системный часовой пояс Europe/Moscow.
#
# После настройки выводится установленное значение часового пояса.
configure_timezone() {
    timedatectl set-timezone Europe/Moscow

    local timezone
    timezone="$(timedatectl show --property=Timezone --value)"

    timedatectl
    log_success "Часовой пояс установлен: $timezone"
}

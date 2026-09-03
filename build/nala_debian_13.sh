#!/usr/bin/env bash

set -euo pipefail

# === colors.sh ===


# Цвета терминала
readonly COLOR_RESET='\033[0m'

readonly COLOR_RED='\033[31m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_BLUE='\033[34m'
readonly COLOR_CYAN='\033[36m'
readonly COLOR_WHITE='\033[37m'

readonly COLOR_BOLD='\033[1m'

readonly COLOR_BOLD_RED='\033[1;31m'
readonly COLOR_BOLD_GREEN='\033[1;32m'
readonly COLOR_BOLD_YELLOW='\033[1;33m'
readonly COLOR_BOLD_BLUE='\033[1;34m'
readonly COLOR_BOLD_CYAN='\033[1;36m'
readonly COLOR_BOLD_WHITE='\033[1;37m'

# === log.sh ===


# ============================
#  Информационное сообщение
# ============================
# Используется для обычных информационных сообщений.
# Вывод направляется в stdout.
log_info() {
    printf '%b[INFO]%b %s\n' \
        "$COLOR_BLUE" \
        "$COLOR_RESET" \
        "$*"
}

# ============================
#  Сообщение о текущем шаге
# ============================
# Используется для обозначения выполняемого действия.
# Например: "Установка Docker..." или "Обновление пакетов..."
# Вывод направляется в stdout.
log_step() {
    printf '%b==>%b %s\n' \
        "$COLOR_BOLD_CYAN" \
        "$COLOR_RESET" \
        "$*"
}

# ============================
#  Сообщение об успешном выполнении
# ============================
# Используется после успешного выполнения операции.
# Вывод направляется в stdout.
log_success() {
    printf '%b✓%b %s\n' \
        "$COLOR_BOLD_GREEN" \
        "$COLOR_RESET" \
        "$*"
}

# ============================
#  Предупреждение
# ============================
# Используется для сообщений, которые не являются критической ошибкой,
# но требуют внимания пользователя.
#
# Предупреждения направляются в stderr.
log_warning() {
    printf '%b[WARN]%b %s\n' \
        "$COLOR_BOLD_YELLOW" \
        "$COLOR_RESET" \
        "$*" >&2
}

# ============================
#  Сообщение об ошибке
# ============================
# Используется для сообщений о возникших ошибках.
#
# Ошибки направляются в stderr, чтобы их можно было
# отдельно обрабатывать от обычного вывода программы.
log_error() {
    printf '%b[ERROR]%b %s\n' \
        "$COLOR_BOLD_RED" \
        "$COLOR_RESET" \
        "$*" >&2
}

# ============================
#  Заголовок раздела
# ============================
# Используется для визуального разделения крупных этапов скрипта.
#
# Например:
#   Настройка локали
#   Установка Docker
#   Настройка SSH
#
# Заголовок принимает один обязательный аргумент — текст.
log_header() {
    local text="$1"
    printf '\n%b%s%b\n' \
        "$COLOR_BOLD_BLUE" \
        "$text" \
        "$COLOR_RESET"
}

# === update_system.sh ===



update_system() {
    log_step "Обновление списка пакетов..."
    apt-get update

    log_success "Список пакетов обновлён"
}

# === workflow: nala_debian_13 ===



# Проверяем операционную систему.
if [[ ! -f /etc/os-release ]]; then
    printf 'Ошибка: файл /etc/os-release не найден\n' >&2
    exit 1
fi

# Загружаем информацию об операционной системе.
# shellcheck disable=SC1091
source /etc/os-release

if [[ "$ID" != "debian" ]]; then
    printf 'Ошибка: поддерживается только Debian\n' >&2
    exit 1
fi

if [[ "$VERSION_ID" != "13" ]]; then
    printf 'Ошибка: поддерживается только Debian 13, обнаружена версия %s\n' \
        "$VERSION_ID" >&2
    exit 1
fi

printf 'Операционная система: Debian %s\n' "$VERSION_ID"

# Обновляем список пакетов.
update_system

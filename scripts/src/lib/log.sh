#!/usr/bin/env bash

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
get_terminal_width() {
    local width

    if command -v tput >/dev/null 2>&1; then
        width="$(tput cols 2>/dev/null || true)"
    fi

    if [[ -z "$width" || "$width" -lt 10 ]]; then
        width="${COLUMNS:-0}"
    fi

    if [[ -z "$width" || "$width" -lt 10 ]]; then
        width=80
    fi

    printf '%s\n' "$width"
}

log_header() {
    local text="$1"
    local width
    local separator

    width="$(get_terminal_width)"

    printf -v separator '%*s' "$width" ''
    separator="${separator// /=}"

    printf '\n%b%s%b\n' \
        "$COLOR_BOLD_BLUE" \
        "$separator" \
        "$COLOR_RESET"

    printf '%b%s%b\n' \
        "$COLOR_BOLD_BLUE" \
        "$text" \
        "$COLOR_RESET"

    printf '%b%s%b\n' \
        "$COLOR_BOLD_BLUE" \
        "$separator" \
        "$COLOR_RESET"
}

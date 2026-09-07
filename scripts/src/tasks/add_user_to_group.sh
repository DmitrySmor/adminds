#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Добавление пользователя в группы
# ============================
# Добавляет указанного пользователя в одну или несколько
# существующих групп.
#
# Пользователь передаётся первым аргументом,
# группы — всеми последующими аргументами.
#
# Например:
#   add_user_to_group "$ORIGINAL_USER" docker
#
# Или:
#   add_user_to_group "$ORIGINAL_USER" sudo www-data developers
#
# Перед добавлением проверяется наличие пользователя
# и каждой указанной группы.
add_user_to_group() {
    local user="${SUDO_USER:-$USER}"

    if ! id "$user" >/dev/null 2>&1; then
        log_error "Пользователь не найден: $user"
        exit 1
    fi

    for group in "$@"; do
        if ! getent group "$group" >/dev/null 2>&1; then
            log_error "Группа не найдена: $group"
            exit 1
        fi

        usermod -aG "$group" "$user"
        log_success "Пользователь $user добавлен в группу $group"
    done

    log_info "Группы пользователя $user:"
    id "$user"
}

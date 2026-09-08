#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Добавление пользователя в группы
# ============================
# Определяет исходного пользователя через SUDO_USER или USER
# и добавляет его в одну или несколько существующих групп.
#
# Группы передаются аргументами функции.
#
# Например:
#   add_user_to_group docker
#
# Или:
#   add_user_to_group sudo www-data developers
#
# Перед добавлением проверяется наличие пользователя
# и каждой указанной группы.
add_user_to_group() {
    local user="${SUDO_USER:-$USER}"

    if [[ "$user" == "root" ]]; then
        log_info "Пользователь root не добавляется в группы"
        return 0
    fi

    if ! id "$user" >/dev/null 2>&1; then
        log_error "Пользователь не найден: $user"
        exit 1
    fi

    for group in "$@"; do
        if ! getent group "$group" >/dev/null 2>&1; then
            log_error "Группа не найдена: $group"
            exit 1
        fi

        if id -nG "$user" | grep -qw "$group"; then
            log_info "Пользователь $user уже состоит в группе $group"
            continue
        fi

        usermod -aG "$group" "$user"
        log_success "Пользователь $user добавлен в группу $group"
    done

    log_info "Группы пользователя $user:"
    id "$user"
}

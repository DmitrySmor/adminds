#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Настройка локали
# ============================
# Устанавливает пакет locales и настраивает системную
# локаль en_US.UTF-8.
#
# После настройки выводится установленное значение локали.
configure_locale() {
    apt-get install -y locales

    printf '%s\n' 'en_US.UTF-8 UTF-8' >/etc/locale.gen

    locale-gen
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

    local lang_value
    lang_value="$(grep '^LANG=' /etc/default/locale | cut -d= -f2)"

    timedatectl
    log_success "Локаль установлена: $lang_value"
}

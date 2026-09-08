#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Базовые пакеты
# ============================
# Общие пакеты, необходимые для
# базовой настройки Debian.
get_base_packages() {
    BASE_PACKAGES=(
        sudo
        tree
        unzip
        zip
        vim
        git
        htop
        curl
        wget
        ca-certificates
        gnupg
        tmux
    )
}

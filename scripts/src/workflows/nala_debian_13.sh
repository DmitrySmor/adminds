#!/usr/bin/env bash

set -euo pipefail

BASE_PACKAGES=(
    sudo
    tree
    unzip
    tar
    gzip
    vim
    git
    htop
    curl
    wget
    apt-transport-https
    ca-certificates
)

log_header "Проверка прав root"
check_root

log_header "Проверка операционной системы"
check_os

log_header "Обновление списка пакетов"
update_system

log_header "Установка пакетов через Nala"
nala_install_packages "${BASE_PACKAGES[@]}"

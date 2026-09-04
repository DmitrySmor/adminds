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

DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

log_header "Проверка прав root"
check_root

log_header "Проверка операционной системы"
check_os

log_header "Настройка локали"
configure_locale

log_header "Настройка часового пояса"
configure_timezone

log_header "Обновление списка пакетов"
update_system

log_header "Установка пакетов через Nala"
nala_install_packages "${BASE_PACKAGES[@]}"

log_header "Добавление репозитория Docker"
add_docker_repository

log_header "Установка Docker через Nala"
nala_install_packages "${DOCKER_PACKAGES[@]}"

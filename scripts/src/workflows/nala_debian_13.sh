#!/usr/bin/env bash

set -euo pipefail

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

# Список пакетов БАЗОВЫЙ
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

log_header "Установка пакетов через Nala"
nala_install_packages "${BASE_PACKAGES[@]}"

log_header "Добавление репозитория Docker"
add_docker_repository

# Список пакетов для докера
DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

log_header "Установка Docker через Nala"
nala_install_packages "${DOCKER_PACKAGES[@]}"

log_header "Очистка кэша Nala"
nala_clean_cache

log_header "Запуск Docker"
start_docker

#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Добавление репозитория Docker
# ============================
# Добавляет официальный репозиторий Docker
# для Debian и обновляет список пакетов.
#
# После выполнения пакеты Docker становятся доступны
# для установки через APT или Nala.
add_docker_repository() {
    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    local version_codename

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ -z "${VERSION_CODENAME:-}" ]]; then
        log_error "VERSION_CODENAME не найден в /etc/os-release"
        exit 1
    fi

    version_codename="$VERSION_CODENAME"

    cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $version_codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt-get update

    mkdir -p /opt/docker/

    log_success "Репозиторий Docker добавлен"
    log_success "Директория Docker /opt/docker/ создана"
}

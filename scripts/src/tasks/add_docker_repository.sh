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

    cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt-get update

    log_success "Репозиторий Docker добавлен"
}

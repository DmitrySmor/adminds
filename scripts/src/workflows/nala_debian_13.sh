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

check_root
check_os
update_system
nala_install_packages "${BASE_PACKAGES[@]}"

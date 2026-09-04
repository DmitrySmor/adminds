#!/usr/bin/env bash

set -euo pipefail

check_root
check_os
update_system
nala_install_packages sudo tree unzip tar gzip vim git htop curl wget apt-transport-https ca-certificates

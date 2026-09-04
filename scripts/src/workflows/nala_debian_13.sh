#!/usr/bin/env bash

set -euo pipefail

check_root
check_os
update_system
nala_install_packages curl wget git

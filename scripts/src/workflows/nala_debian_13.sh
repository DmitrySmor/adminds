#!/usr/bin/env bash

set -euo pipefail

# проверка прав root
check_root

# Проверка операционной системы
check_os

# Обновляем список пакетов.
update_system

# Установка пакета Nala
install_nala

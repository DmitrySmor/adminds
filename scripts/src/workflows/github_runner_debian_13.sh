#!/usr/bin/env bash

set -euo pipefail

log_header "Проверка прав root"
check_root

log_header "Проверка операционной системы"
check_os

log_header "Обновление списка пакетов"
update_system

log_header "Очистка кэша Nala"
nala_clean_cache

#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# Установка Hawser Edge агента для Dockhand.
#
# Все глобальные переменные HAWSER_* и константы путей объявлены
# в task hawser_edge_check (см. scripts/src/tasks/hawser_edge_check.sh).
# ==============================================================================

log_header "Проверка прав root"
check_root

log_header "Проверка Hawser Edge"
hawser_edge_check

# log_header "Установка Hawser Edge"
# hawser_edge_install

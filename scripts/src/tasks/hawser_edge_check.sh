#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# Task: hawser_edge_check
# ==============================================================================
# Проверяет состояние системы и установки Hawser Edge агента.
#
# Ничего не запрашивает у пользователя.
# Ничего не изменяет в системе.
# Ничего не возвращает.
#
# Используется во всех Hawser workflow: install / update / remove.
#
# ------------------------------------------------------------------------------
# Константы путей:
# ------------------------------------------------------------------------------
HAWSER_BIN_PATH="/usr/local/bin/hawser"
HAWSER_UNIT_PATH="/etc/systemd/system/hawser.service"
HAWSER_CONFIG_PATH="/etc/hawser/config"
HAWSER_STACKS_DIR="/opt/docker"
HAWSER_DOCKER_SOCKET="/var/run/docker.sock"
HAWSER_SERVICE_NAME="hawser.service"

# --- Параметры подключения по умолчанию ---
# Используются, если конфиг отсутствует или параметр в нём не задан.
# Проверяются в конфиге /etc/hawser/config:
#   DOCKHAND_SERVER_URL — URL сервера Dockhand
#   TOKEN               — токен агента из Dockhand
DOCKHAND_SERVER_URL="dockhand.energo-effect.pro"
DOCKHAND_SERVER_TOKEN=""

# ------------------------------------------------------------------------------
# Глобальные переменные (результат):
# ------------------------------------------------------------------------------
#   HAWSER_INSTALLED          true/false — агент установлен
#   HAWSER_SERVICE_ACTIVE     true/false — сервис запущен
#   HAWSER_SERVICE_ENABLED    true/false — сервис в автозапуске
#   DOCKHAND_SERVER_URL       строка     — URL Dockhand (из конфига или default)
#   DOCKHAND_SERVER_TOKEN     строка     — токен агента (из конфига или default)
# ==============================================================================

hawser_edge_check() {
    # --- Инициализация результатов (default: ничего не установлено) ---
    HAWSER_INSTALLED="false"
    HAWSER_SERVICE_ACTIVE="false"
    HAWSER_SERVICE_ENABLED="false"

    # ==========================================================
    # Группа 1: Pre-flight проверки (логируются, не блокируют)
    # ==========================================================

    # --- архитектура ---
    local raw_arch arch
    raw_arch="$(uname -m)"
    case "${raw_arch}" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    armv7l | armv7 | arm) arch="arm" ;;
    *)
        log_error "неподдерживаемая архитектура — ${raw_arch}"
        arch=""
        ;;
    esac
    [[ -n "${arch}" ]] && log_info "архитектура — ${arch}"

    # --- systemctl ---
    if command -v systemctl >/dev/null 2>&1; then
        log_success "systemctl — OK"
    else
        log_error "systemctl не найден"
    fi

    # --- docker.service существует ---
    if systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service'; then
        log_success "docker.service найден"
    else
        log_error "docker.service не найден"
    fi

    # --- docker socket ---
    if [[ -S "${HAWSER_DOCKER_SOCKET}" ]]; then
        log_success "${HAWSER_DOCKER_SOCKET} — OK"
    else
        log_error "${HAWSER_DOCKER_SOCKET} не найден"
    fi

    # --- docker.service active ---
    if systemctl is-active --quiet docker 2>/dev/null; then
        log_success "docker.service активен"
    else
        log_error "docker.service не активен"
    fi

    # --- GitHub API ---
    if curl -fsSL --max-time 10 \
        "https://api.github.com/repos/Finsys/hawser/releases/latest" \
        >/dev/null 2>&1; then
        log_success "GitHub API доступен"
    else
        log_error "GitHub API недоступен"
    fi

    # ==========================================================
    # Группа 2: Состояние установки
    # ==========================================================

    # --- бинарник ---
    if [[ -x "${HAWSER_BIN_PATH}" ]]; then
        log_success "бинарник найден — ${HAWSER_BIN_PATH}"
    else
        log_error "бинарник отсутствует"
    fi

    # --- systemd unit ---
    if [[ -f "${HAWSER_UNIT_PATH}" ]]; then
        log_success "unit найден — ${HAWSER_UNIT_PATH}"
    else
        log_error "unit отсутствует"
    fi

    # --- конфиг ---
    if [[ -f "${HAWSER_CONFIG_PATH}" ]]; then
        log_success "конфиг найден — ${HAWSER_CONFIG_PATH}"

        # --- DOCKHAND_SERVER_URL ---
        local cfg_url
        cfg_url="$(grep -E '^DOCKHAND_SERVER_URL=' "${HAWSER_CONFIG_PATH}" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
        if [[ -n "${cfg_url}" ]]; then
            DOCKHAND_SERVER_URL="${cfg_url}"
            log_success "DOCKHAND_SERVER_URL — ${DOCKHAND_SERVER_URL}"
        else
            log_error "DOCKHAND_SERVER_URL не задан, default: ${DOCKHAND_SERVER_URL}"
        fi

        # --- TOKEN ---
        local cfg_token
        cfg_token="$(grep -E '^TOKEN=' "${HAWSER_CONFIG_PATH}" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
        if [[ -n "${cfg_token}" ]]; then
            DOCKHAND_SERVER_TOKEN="${cfg_token}"
            log_success "TOKEN — задан"
        else
            log_error "TOKEN — не задан"
        fi
    else
        log_error "конфиг отсутствует — ${HAWSER_CONFIG_PATH}"
        log_info "DOCKHAND_SERVER_URL — default: ${DOCKHAND_SERVER_URL}"
        log_info "TOKEN — default: не задан"
    fi

    # --- сервис enabled ---
    if systemctl is-enabled --quiet "${HAWSER_SERVICE_NAME}" 2>/dev/null; then
        HAWSER_SERVICE_ENABLED="true"
        log_success "сервис в автозапуске"
    else
        log_error "сервис не в автозапуске"
    fi

    # --- сервис active ---
    if systemctl is-active --quiet "${HAWSER_SERVICE_NAME}" 2>/dev/null; then
        HAWSER_SERVICE_ACTIVE="true"
        log_success "сервис активен"
    else
        log_error "сервис не активен"
    fi

    # --- версия (только вывод) ---
    if [[ -x "${HAWSER_BIN_PATH}" ]]; then
        local version
        version="$("${HAWSER_BIN_PATH}" --version 2>/dev/null | head -n1 || true)"
        [[ -n "${version}" ]] && log_info "версия — ${version}"
    fi

    # --- Итог: установлен ли агент ---
    if [[ -x "${HAWSER_BIN_PATH}" ]] && [[ -f "${HAWSER_UNIT_PATH}" ]]; then
        HAWSER_INSTALLED="true"
        log_info "Результат: Hawser Edge установлен"
    else
        HAWSER_INSTALLED="false"
        log_info "Результат: Hawser Edge не установлен"
    fi
}

#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# Task: hawser_edge_install
# ==============================================================================
# Установка Hawser Edge агента для Dockhand.
#
# Предполагает, что перед вызовом уже выполнен hawser_edge_check,
# который заполнил DOCKHAND_SERVER_URL и DOCKHAND_SERVER_TOKEN из конфига
# (или оставил значения по умолчанию).
#
# Интерактивный ввод:
#   TOKEN — обязателен, если не задан из конфига
#   URL   — опционален, при пустом вводе используется текущее значение
#
# Глобальные переменные (использует):
#   HAWSER_INSTALLED, HAWSER_BIN_PATH, HAWSER_UNIT_PATH,
#   HAWSER_CONFIG_PATH, HAWSER_STACKS_DIR, HAWSER_DOCKER_SOCKET,
#   HAWSER_SERVICE_NAME, DOCKHAND_SERVER_URL, DOCKHAND_SERVER_TOKEN
# ==============================================================================

# --- Вспомогательная функция: безопасное чтение из терминала ---
# Использование: _hawser_read_from_tty <prompt> <var_name> [default]
# Работает даже при запуске через `curl | sudo bash`.
_hawser_read_from_tty() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local input

    while true; do
        read -rp "${prompt}" input </dev/tty
        if [[ -n "${input}" ]]; then
            eval "${var_name}=\"${input}\""
            return 0
        elif [[ -n "${default_value}" ]]; then
            eval "${var_name}=\"${default_value}\""
            return 0
        else
            log_error "поле не может быть пустым. Попробуйте снова."
        fi
    done
}

hawser_edge_install() {
    # --- Уже установлен ---
    if [[ "${HAWSER_INSTALLED}" == "true" ]]; then
        log_warning "Hawser Edge уже установлен"
        return 0
    fi

    # ==========================================================
    # Параметры установки
    # ==========================================================

    # --- TOKEN ---
    # Если уже задан (из конфига) — используем.
    # Если пуст — запрашиваем интерактивно (обязательно).
    if [[ -n "${DOCKHAND_SERVER_TOKEN}" ]]; then
        log_info "TOKEN взят из конфига"
    else
        _hawser_read_from_tty "Введите токен агента (из Dockhand): " DOCKHAND_SERVER_TOKEN
    fi

    # --- DOCKHAND_SERVER_URL ---
    # Если задан — используем.
    # Если пуст — запрашиваем домен (с текущим значением как default).
    if [[ -n "${DOCKHAND_SERVER_URL}" ]]; then
        log_info "DOCKHAND_SERVER_URL взят из конфига: ${DOCKHAND_SERVER_URL}"
    else
        _hawser_read_from_tty "Введите домен Dockhand: " DOCKHAND_SERVER_URL
    fi

    # Если введён домен без схемы — достраиваем до полного URL
    if [[ "${DOCKHAND_SERVER_URL}" != wss://* && "${DOCKHAND_SERVER_URL}" != ws://* ]]; then
        DOCKHAND_SERVER_URL="wss://${DOCKHAND_SERVER_URL}/api/hawser/connect"
    fi

    log_info "DOCKHAND_SERVER_URL = ${DOCKHAND_SERVER_URL}"
    log_info "TOKEN               = ***"

    # --- Определение ОС и архитектуры ---
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    armv7l | armv7 | arm) arch="arm" ;;
    *)
        log_error "неподдерживаемая архитектура"
        return 1
        ;;
    esac

    # --- Получение последней версии ---
    log_info "определение последней версии Hawser..."
    local latest_version
    latest_version="$(curl -fsSL "https://api.github.com/repos/Finsys/hawser/releases/latest" |
        grep '"tag_name"' |
        sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/')"
    if [[ -z "${latest_version}" ]]; then
        log_error "не удалось получить последнюю версию с GitHub"
        return 1
    fi
    log_info "последняя версия: ${latest_version}"

    # --- Формирование URL ---
    local download_url
    download_url="https://github.com/Finsys/hawser/releases/download/v${latest_version}/hawser_${latest_version}_${os}_${arch}.tar.gz"
    log_info "загрузка из: ${download_url}"

    # --- Временная директория ---
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmp_dir}'" RETURN

    # --- Скачивание ---
    log_info "скачивание бинарного файла..."
    if ! curl -fsSL -o "${tmp_dir}/hawser.tar.gz" "${download_url}"; then
        log_error "ошибка загрузки. Проверьте доступность релиза."
        return 1
    fi

    # --- Распаковка ---
    log_info "распаковка..."
    tar -xzf "${tmp_dir}/hawser.tar.gz" -C "${tmp_dir}"

    # --- Установка бинарника ---
    log_info "установка ${HAWSER_BIN_PATH} ..."
    install -m 755 "${tmp_dir}/hawser" "${HAWSER_BIN_PATH}"

    # --- Каталог стеков ---
    log_info "создание ${HAWSER_STACKS_DIR} ..."
    mkdir -p "${HAWSER_STACKS_DIR}"

    # --- Конфиг ---
    log_info "создание ${HAWSER_CONFIG_PATH} ..."
    mkdir -p "$(dirname "${HAWSER_CONFIG_PATH}")"
    cat >"${HAWSER_CONFIG_PATH}" <<CFG
# Edge Mode — соединение по WebSocket
DOCKHAND_SERVER_URL=${DOCKHAND_SERVER_URL}
TOKEN=${DOCKHAND_SERVER_TOKEN}

STACKS_DIR=${HAWSER_STACKS_DIR}
DOCKER_SOCKET=${HAWSER_DOCKER_SOCKET}
CFG
    chmod 600 "${HAWSER_CONFIG_PATH}"

    # --- Systemd unit ---
    log_info "создание ${HAWSER_UNIT_PATH} ..."
    cat >"${HAWSER_UNIT_PATH}" <<'UNIT'
[Unit]
Description=Hawser Agent (Edge Mode) for Dockhand
Documentation=https://github.com/Finsys/hawser
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hawser
Restart=always
RestartSec=10
EnvironmentFile=/etc/hawser/config

NoNewPrivileges=false
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/run/docker.sock /opt/docker /etc/hawser

[Install]
WantedBy=multi-user.target
UNIT

    # --- Запуск сервиса ---
    log_info "запуск ${HAWSER_SERVICE_NAME}..."
    systemctl daemon-reload
    systemctl enable --now hawser

    # --- Проверка статуса ---
    log_success "установка завершена"
    log_info "для просмотра логов: journalctl -u hawser -f"
}

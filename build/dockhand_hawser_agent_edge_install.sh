#!/usr/bin/env bash

set -euo pipefail

# ============================
# Цвета терминала
# ============================
readonly COLOR_RESET='\033[0m'

readonly COLOR_BLUE='\033[34m'

readonly COLOR_BOLD_RED='\033[1;31m'
readonly COLOR_BOLD_GREEN='\033[1;32m'
readonly COLOR_BOLD_YELLOW='\033[1;33m'
readonly COLOR_BOLD_CYAN='\033[1;36m'

# ============================
#  Получение ширины терминала
# ============================
# Определяет текущую ширину терминала.
#
# Сначала используется размер терминала из /dev/tty,
# затем значение переменной COLUMNS.
# Если определить ширину не удалось, используется значение 80.
get_terminal_width() {
	local width

	if [[ -r /dev/tty ]] && command -v stty >/dev/null 2>&1; then
		width="$(stty size </dev/tty 2>/dev/null | awk '{print $2}')"
	fi

	if [[ -z "$width" || "$width" -lt 10 ]]; then
		width="${COLUMNS:-0}"
	fi

	if [[ -z "$width" || "$width" -lt 10 ]]; then
		width=80
	fi

	printf '%s\n' "$width"
}

# ============================
#  Информационное сообщение
# ============================
# Используется для обычных информационных сообщений.
#
# Например: "[INFO] Запущена настройка системы".
#
# Вывод направляется в stdout.
log_info() {
	printf '%b[INFO]%b %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

# ============================
#  Сообщение о текущем шаге
# ============================
# Используется для обозначения выполняемого действия.
#
# Например: "==> Установка пакетов".
#
# Вывод направляется в stdout.
log_step() {
	printf '%b==>%b %s\n' "$COLOR_BOLD_CYAN" "$COLOR_RESET" "$*"
}

# ============================
#  Сообщение об успешном выполнении
# ============================
# Используется после успешного выполнения операции.
#
# Например: "✓ Права root подтверждены" или "✓ Пакеты установлены".
#
# Вывод направляется в stdout.
log_success() {
	printf '%b✓ %s%b\n' "$COLOR_BOLD_GREEN" "$*" "$COLOR_RESET"
}

# ============================
#  Предупреждение
# ============================
# Используется для сообщений, которые не являются критической ошибкой,
# но требуют внимания пользователя.
#
# Например: "[WARN] Пакет уже установлен".
#
# Вывод направляется в stderr.
log_warning() {
	printf '%b[WARN]%b %s\n' "$COLOR_BOLD_YELLOW" "$COLOR_RESET" "$*" >&2
}

# ============================
#  Сообщение об ошибке
# ============================
# Используется для сообщений о возникших ошибках.
#
# Например: "[ERROR] Скрипт должен быть запущен от имени root".
#
# Вывод направляется в stderr.
log_error() {
	printf '%b[ERROR]%b %s\n' "$COLOR_BOLD_RED" "$COLOR_RESET" "$*" >&2
}

# ============================
#  Заголовок раздела
# ============================
# Используется для визуального разделения крупных этапов скрипта.
#
# Например:
#   ================================
#   Проверка прав root
#   ================================
#
# Заголовок выводится в стандартном цвете терминала.
log_header() {
	local text="$1"
	local width
	local separator

	width="$(get_terminal_width)"

	printf -v separator '%*s' "$width" ''
	separator="${separator// /=}"

	printf '\n%s\n' "$separator"
	printf '%s\n' "$text"
	printf '%s\n' "$separator"
}

# ============================
#  Проверка прав root
# ============================
# Проверяет, запущен ли скрипт с правами пользователя root.
#
# При отсутствии прав root выполнение скрипта прекращается
# с сообщением об ошибке.
#
# При успешной проверке выводится подтверждение.
check_root() {
	if [[ "$EUID" -ne 0 ]]; then
		log_error "Скрипт должен быть запущен от имени root"
		exit 1
	fi

	id
	log_success "Права root подтверждены"
}

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
	[[ -n "${arch}" ]] && log_success "архитектура — ${arch}"

	# --- systemctl ---
	if command -v systemctl >/dev/null 2>&1; then
		log_success "systemctl — OK"
	else
		log_error "systemctl не найден"
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
		log_error "TOKEN: не задан"
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
		[[ -n "${version}" ]] && log_success "версия — ${version}"
	fi

	# --- Итог: установлен ли агент ---
	if [[ -x "${HAWSER_BIN_PATH}" ]] && [[ -f "${HAWSER_UNIT_PATH}" ]]; then
		HAWSER_INSTALLED="true"
		log_success "Hawser Edge установлен"
	else
		HAWSER_INSTALLED="false"
		log_error "Hawser Edge не установлен"
	fi
}

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

log_header "Установка Hawser Edge"
hawser_edge_install

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
#
# ------------------------------------------------------------------------------
# Глобальные переменные (результат):
# ------------------------------------------------------------------------------
#   HAWSER_INSTALLED          true/false — агент установлен
#   HAWSER_SERVICE_ACTIVE     true/false — сервис запущен
#   HAWSER_SERVICE_ENABLED    true/false — сервис в автозапуске
# ==============================================================================

hawser_edge_check() {
	# --- Инициализация результатов (default: ничего не установлено) ---
	HAWSER_INSTALLED="false"
	HAWSER_SERVICE_ACTIVE="false"
	HAWSER_SERVICE_ENABLED="false"

	log_info "=== Hawser Edge: проверка системы ==="

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
		log_warn "неподдерживаемая архитектура — ${raw_arch}"
		arch=""
		;;
	esac
	[[ -n "${arch}" ]] && log_info "архитектура — ${arch}"

	# --- systemctl ---
	if command -v systemctl >/dev/null 2>&1; then
		log_info "systemctl — OK"
	else
		log_warn "systemctl не найден"
	fi

	# --- docker.service существует ---
	if systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service'; then
		log_info "docker.service найден"
	else
		log_warn "docker.service не найден"
	fi

	# --- docker socket ---
	if [[ -S "${HAWSER_DOCKER_SOCKET}" ]]; then
		log_info "${HAWSER_DOCKER_SOCKET} — OK"
	else
		log_warn "${HAWSER_DOCKER_SOCKET} не найден"
	fi

	# --- docker.service active ---
	if systemctl is-active --quiet docker 2>/dev/null; then
		log_info "docker.service активен"
	else
		log_warn "docker.service не активен"
	fi

	# --- GitHub API ---
	if curl -fsSL --max-time 10 \
		"https://api.github.com/repos/Finsys/hawser/releases/latest" \
		>/dev/null 2>&1; then
		log_info "GitHub API доступен"
	else
		log_warn "GitHub API недоступен"
	fi

	# ==========================================================
	# Группа 2: Состояние установки
	# ==========================================================
	log_info "=== Hawser Edge: состояние установки ==="

	# --- бинарник ---
	if [[ -x "${HAWSER_BIN_PATH}" ]]; then
		log_info "бинарник найден — ${HAWSER_BIN_PATH}"
	else
		log_info "бинарник отсутствует"
	fi

	# --- systemd unit ---
	if [[ -f "${HAWSER_UNIT_PATH}" ]]; then
		log_info "unit найден — ${HAWSER_UNIT_PATH}"
	else
		log_info "unit отсутствует"
	fi

	# --- конфиг ---
	if [[ -f "${HAWSER_CONFIG_PATH}" ]]; then
		log_info "конфиг найден — ${HAWSER_CONFIG_PATH}"
	else
		log_info "конфиг отсутствует"
	fi

	# --- сервис enabled ---
	if systemctl is-enabled --quiet "${HAWSER_SERVICE_NAME}" 2>/dev/null; then
		HAWSER_SERVICE_ENABLED="true"
		log_info "сервис в автозапуске"
	else
		log_info "сервис не в автозапуске"
	fi

	# --- сервис active ---
	if systemctl is-active --quiet "${HAWSER_SERVICE_NAME}" 2>/dev/null; then
		HAWSER_SERVICE_ACTIVE="true"
		log_info "сервис активен"
	else
		log_info "сервис не активен"
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

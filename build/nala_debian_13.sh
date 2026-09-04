#!/usr/bin/env bash

set -euo pipefail

# ============================
# Цвета терминала
# ============================
readonly COLOR_RESET='\033[0m'

readonly COLOR_RED='\033[31m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_BLUE='\033[34m'
readonly COLOR_CYAN='\033[36m'
readonly COLOR_WHITE='\033[37m'

readonly COLOR_BOLD='\033[1m'

readonly COLOR_BOLD_RED='\033[1;31m'
readonly COLOR_BOLD_GREEN='\033[1;32m'
readonly COLOR_BOLD_YELLOW='\033[1;33m'
readonly COLOR_BOLD_BLUE='\033[1;34m'
readonly COLOR_BOLD_CYAN='\033[1;36m'
readonly COLOR_BOLD_WHITE='\033[1;37m'

# ============================
#  Информационное сообщение
# ============================
# Используется для обычных информационных сообщений.
# Вывод направляется в stdout.
log_info() {
	printf '%b[INFO]%b %s\n' \
		"$COLOR_BLUE" \
		"$COLOR_RESET" \
		"$*"
}

# ============================
#  Сообщение о текущем шаге
# ============================
# Используется для обозначения выполняемого действия.
# Например: "Установка Docker..." или "Обновление пакетов..."
# Вывод направляется в stdout.
log_step() {
	printf '%b==>%b %s\n' \
		"$COLOR_BOLD_CYAN" \
		"$COLOR_RESET" \
		"$*"
}

# ============================
#  Сообщение об успешном выполнении
# ============================
# Используется после успешного выполнения операции.
# Вывод направляется в stdout.
log_success() {
	printf '%b✓%b %s\n' \
		"$COLOR_BOLD_GREEN" \
		"$COLOR_RESET" \
		"$*"
}

# ============================
#  Предупреждение
# ============================
# Используется для сообщений, которые не являются критической ошибкой,
# но требуют внимания пользователя.
#
# Предупреждения направляются в stderr.
log_warning() {
	printf '%b[WARN]%b %s\n' \
		"$COLOR_BOLD_YELLOW" \
		"$COLOR_RESET" \
		"$*" >&2
}

# ============================
#  Сообщение об ошибке
# ============================
# Используется для сообщений о возникших ошибках.
#
# Ошибки направляются в stderr, чтобы их можно было
# отдельно обрабатывать от обычного вывода программы.
log_error() {
	printf '%b[ERROR]%b %s\n' \
		"$COLOR_BOLD_RED" \
		"$COLOR_RESET" \
		"$*" >&2
}

# ============================
#  Заголовок раздела
# ============================
# Используется для визуального разделения крупных этапов скрипта.
#
# Например:
#   Настройка локали
#   Установка Docker
#   Настройка SSH
#
# Заголовок принимает один обязательный аргумент — текст.
# get_terminal_width() {
#     local width

#     width="${COLUMNS:-}"

#     if [[ -z "$width" ]] && command -v tput >/dev/null 2>&1; then
#         width="$(tput cols 2>/dev/null || true)"
#     fi

#     if [[ -z "$width" || "$width" -lt 1 ]]; then
#         width=80
#     fi

#     printf '%s\n' "$width"
# }

# log_header() {
#     local text="$1"
#     local width
#     local separator

#     width="$(get_terminal_width)"

#     printf -v separator '%*s' "$width" ''
#     separator="${separator// /=}"

#     printf '\n%b%s%b\n' \
#         "$COLOR_BOLD_BLUE" \
#         "$separator" \
#         "$COLOR_RESET"

#     printf '%b%s%b\n' \
#         "$COLOR_BOLD_BLUE" \
#         "$text" \
#         "$COLOR_RESET"
# }

get_terminal_width() {
	local width=80
	if command -v stty &>/dev/null; then
		width=$(stty size 2>/dev/null | cut -d' ' -f2)
	fi
	if [[ -z "$width" || "$width" -eq 0 ]]; then
		width=${COLUMNS:-0}
	fi
	if [[ "$width" -eq 0 ]] && command -v tput &>/dev/null; then
		width=$(tput cols 2>/dev/null)
	fi
	if [[ "$width" -lt 10 ]]; then
		width=80
	fi
	echo "$width"
}

log_header() {
	local text="$1"
	local cols=$(get_terminal_width)
	local text_len=${#text}
	local total_len=$cols

	if ((text_len + 2 > total_len)); then
		echo -e "\033[1;34m$text\033[0m"
		return
	fi

	local padding=$(((total_len - text_len - 2) / 2))
	local remainder=$(((total_len - text_len - 2) % 2))
	local left_padding=$((padding + remainder))
	local right_padding=$padding

	local left_line right_line
	printf -v left_line '%*s' "$left_padding" ''
	left_line=${left_line// /=}
	printf -v right_line '%*s' "$right_padding" ''
	right_line=${right_line// /=}

	echo -e "\033[1;34m${left_line} ${text} ${right_line}\033[0m"
}

check_root() {
	if [[ "$EUID" -ne 0 ]]; then
		log_error "Скрипт должен быть запущен от имени root"
		exit 1
	fi

	log_success "Права root подтверждены"
}

# Проверка операционной системы

check_os() {
	if [[ ! -f /etc/os-release ]]; then
		log_error "Файл /etc/os-release не найден"
		exit 1
	fi

	# shellcheck disable=SC1091
	source /etc/os-release

	if [[ "$ID" != "debian" ]]; then
		log_error "Поддерживается только Debian"
		exit 1
	fi

	if [[ "$VERSION_ID" != "13" ]]; then
		log_error "Поддерживается только Debian 13, обнаружена версия $VERSION_ID"
		exit 1
	fi

	log_success "Операционная система: Debian $VERSION_ID"
}

update_system() {
	apt-get update
	log_success "Список пакетов обновлён"
}

nala_install_packages() {
	if ! command -v nala >/dev/null 2>&1; then
		apt-get install -y nala
		if ! command -v nala >/dev/null 2>&1; then
			log_error "Nala не установлен"
			exit 1
		fi
		log_success "Nala установлен"
	fi
	nala install -y "$@"
	log_success "Пакеты установлены"
}
# === workflow: nala_debian_13 ===

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

log_header "Проверка прав root"
check_root

log_header "Проверка операционной системы"
check_os

log_header "Обновление списка пакетов"
update_system

log_header "Установка пакетов через Nala"
nala_install_packages "${BASE_PACKAGES[@]}"

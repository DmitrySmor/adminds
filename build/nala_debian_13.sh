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
log_header() {
	local text="$1"
	printf '\n%b%s%b\n' \
		"$COLOR_BOLD_BLUE" \
		"$text" \
		"$COLOR_RESET"
}

# Провека Операционный системы

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
	log_step "Обновление списка пакетов..."
	apt-get update

	log_success "Список пакетов обновлён"
}

install_nala() {
	log_step "Установка Nala..."

	apt-get install -y nala

	if ! command -v nala >/dev/null 2>&1; then
		log_error "Nala не установлен"
		exit 1
	fi

	log_success "Nala установлен"
}
# === workflow: nala_debian_13 ===

# Проверка операционной системы
check_os

# Обновляем список пакетов.
update_system

# Установка пакета Nala
install_nala

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
#  Добавление пользователя в группы
# ============================
# Определяет исходного пользователя через SUDO_USER или USER
# и добавляет его в одну или несколько существующих групп.
#
# Группы передаются аргументами функции.
#
# Например:
#   add_user_to_group docker
#
# Или:
#   add_user_to_group sudo www-data developers
#
# Перед добавлением проверяется наличие пользователя
# и каждой указанной группы.
add_user_to_group() {
	local user="${SUDO_USER:-$USER}"

	if ! id "$user" >/dev/null 2>&1; then
		log_error "Пользователь не найден: $user"
		exit 1
	fi

	for group in "$@"; do
		if ! getent group "$group" >/dev/null 2>&1; then
			log_error "Группа не найдена: $group"
			exit 1
		fi

		usermod -aG "$group" "$user"
		log_success "Пользователь $user добавлен в группу $group"
	done

	log_info "Группы пользователя $user:"
	id "$user"
}

# ============================
#  Базовые пакеты
# ============================
# Общие пакеты, необходимые для
# базовой настройки Debian.
get_base_packages() {
	BASE_PACKAGES=(
		sudo
		tree
		unzip
		zip
		vim
		git
		htop
		curl
		wget
		ca-certificates
		gnupg
		tmux
	)
}

# ============================
#  Проверка операционной системы
# ============================
# Проверяет наличие файла /etc/os-release,
# а также соответствие операционной системы Debian 13.
#
# При успешной проверке выводится подтверждение версии системы.
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

	cat /etc/os-release
	log_success "Операционная система: Debian $VERSION_ID"
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

# ============================
#  Настройка локали
# ============================
# Устанавливает пакет locales и настраивает системную
# локаль en_US.UTF-8.
#
# После настройки выводится установленное значение локали.
configure_locale() {
	apt-get install -y locales

	printf '%s\n' 'en_US.UTF-8 UTF-8' >/etc/locale.gen

	locale-gen
	update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

	local lang_value
	lang_value="$(grep '^LANG=' /etc/default/locale | cut -d= -f2)"

	locale
	log_success "Локаль установлена: $lang_value"
}

# ============================
#  Настройка часового пояса
# ============================
# Устанавливает системный часовой пояс Europe/Moscow.
#
# После настройки выводится установленное значение часового пояса.
configure_timezone() {
	timedatectl set-timezone Europe/Moscow

	local timezone
	timezone="$(timedatectl show --property=Timezone --value)"

	timedatectl
	log_success "Часовой пояс установлен: $timezone"
}

# ============================
#  Добавление репозитория Docker
# ============================
# Добавляет официальный репозиторий Docker
# для Debian и обновляет список пакетов.
#
# После выполнения пакеты Docker становятся доступны
# для установки через APT или Nala.
add_docker_repository() {
	install -m 0755 -d /etc/apt/keyrings

	curl -fsSL https://download.docker.com/linux/debian/gpg \
		-o /etc/apt/keyrings/docker.asc

	chmod a+r /etc/apt/keyrings/docker.asc

	local version_codename

	# shellcheck disable=SC1091
	source /etc/os-release

	if [[ -z "${VERSION_CODENAME:-}" ]]; then
		log_error "VERSION_CODENAME не найден в /etc/os-release"
		exit 1
	fi

	version_codename="$VERSION_CODENAME"

	cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $version_codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

	apt-get update

	mkdir -p /opt/docker/

	log_success "Репозиторий Docker добавлен"
	log_success "Директория Docker /opt/docker/ создана"
}

# ============================
#  Запуск Docker
# ============================
# Включает Docker при загрузке системы
# и запускает сервис Docker.
#
# После запуска выводится состояние сервиса.
start_docker() {
	systemctl enable --now docker
	systemctl status docker --no-pager | head -5

	log_success "Docker запущен"
}

# ============================
#  Очистка кэша Nala
# ============================
# Очищает локальный кэш загруженных пакетов Nala.
#
# После очистки выводится подтверждение.
nala_clean_cache() {
	nala clean
	log_success "Кэш Nala очищен"
}

# ============================
#  Установка пакетов через Nala
# ============================
# Проверяет наличие Nala и устанавливает его через APT,
# если Nala ещё не установлен.
#
# После установки Nala устанавливает переданные пакеты.
#
# Например: nala_install_packages curl git vim
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

# ============================
#  Обновление списка пакетов
# ============================
# Обновляет локальный список доступных пакетов
# из настроенных репозиториев Debian.
#
# После успешного выполнения выводится подтверждение обновления.
update_system() {
	apt-get update
	log_success "Список пакетов обновлён"
}

log_header "Проверка прав root"
check_root

log_header "Проверка операционной системы"
check_os

log_header "Настройка локали"
configure_locale

log_header "Настройка часового пояса"
configure_timezone

log_header "Обновление списка пакетов"
update_system

log_header "Установка пакетов через Nala"
# Получение списка базовых пакетов BASE_PACKAGES
get_base_packages
nala_install_packages "${BASE_PACKAGES[@]}"

log_header "Добавление репозитория Docker"
add_docker_repository

# Список пакетов для докера
DOCKER_PACKAGES=(
	docker-ce
	docker-ce-cli
	containerd.io
	docker-buildx-plugin
	docker-compose-plugin
)

log_header "Установка Docker через Nala"
nala_install_packages "${DOCKER_PACKAGES[@]}"

log_header "Очистка кэша Nala"
nala_clean_cache

log_header "Запуск Docker"
start_docker

log_header "Добавление пользователя в группы"
add_user_to_group docker

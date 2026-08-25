#!/bin/bash
set -e
set -o pipefail

# ============================
#  Функции для красивого вывода
# ============================

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

print_header() {
    local text="$1"
    local cols=$(get_terminal_width)
    local text_len=${#text}
    local total_len=$cols

    if (( text_len + 2 > total_len )); then
        echo -e "\033[1;34m$text\033[0m"
        return
    fi

    local padding=$(( (total_len - text_len - 2) / 2 ))
    local remainder=$(( (total_len - text_len - 2) % 2 ))
    local left_padding=$((padding + remainder))
    local right_padding=$padding

    local left_line right_line
    printf -v left_line '%*s' "$left_padding" ''
    left_line=${left_line// /=}
    printf -v right_line '%*s' "$right_padding" ''
    right_line=${right_line// /=}

    echo -e "\033[1;34m${left_line} ${text} ${right_line}\033[0m"
}

print_substep() {
    echo -e "\033[1;36m==>\033[0m $1"
}

print_error() {
    echo -e "\033[1;31mОшибка:\033[0m $1" >&2
}

print_success() {
    echo -e "\033[1;32m✓\033[0m $1"
}

# ============================
#  Обработка ошибок и прерываний
# ============================

cleanup() {
    print_error "Скрипт прерван. Система может быть в нестабильном состоянии."
    exit 1
}
trap cleanup SIGINT SIGTERM

# ============================
#  Проверка прав и дистрибутива
# ============================

if [ "$EUID" -ne 0 ]; then
    print_error "Скрипт должен быть запущен с правами root (используйте sudo)."
    exit 2
fi

if ! grep -qi "debian" /etc/os-release; then
    print_error "Скрипт предназначен только для Debian."
    exit 3
fi

print_header "Настройка сервера Debian"

# Запоминаем пользователя, который запустил sudo (для добавления в группу docker)
ORIGINAL_USER=${SUDO_USER:-$USER}

# ============================
#  1. Обновление и установка nala
# ============================

print_header "Обновление системы и установка nala"
print_substep "Обновление списка пакетов..."
apt update

if ! command -v nala &>/dev/null; then
    print_substep "Установка nala..."
    apt install -y nala
else
    print_success "nala уже установлен"
fi

print_substep "Обновление всех пакетов через nala..."
nala upgrade -y

# ============================
#  2. Настройка локали
# ============================

print_header "Настройка локали (en_US.UTF-8)"
DEBIAN_FRONTEND=noninteractive nala install -y locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
print_success "Локаль установлена: $(locale | head -1)"

# ============================
#  3. Часовой пояс
# ============================

print_header "Установка часового пояса (Europe/Moscow)"
timedatectl set-timezone Europe/Moscow
print_success "Часовой пояс: $(timedatectl show --property=Timezone --value)"

# ============================
#  4. Базовые утилиты
# ============================

print_header "Установка базовых утилит"
nala install -y sudo tree unzip tar gzip vim git htop curl wget apt-transport-https ca-certificates
print_success "Базовые утилиты установлены"

# ============================
#  5. Очистка кэша
# ============================

print_header "Очистка кэша nala"
nala clean
print_success "Кэш очищен"

# ============================
#  6. Установка Docker
# ============================

print_header "Установка Docker"

if command -v docker &>/dev/null; then
    print_success "Docker уже установлен: $(docker --version)"
else
    print_substep "Установка зависимостей для Docker..."
    nala install -y gnupg lsb-release

    mkdir -p /opt/docker/
    install -m 0755 -d /etc/apt/keyrings

    print_substep "Добавление официального репозитория Docker..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor > /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Определяем кодовое имя дистрибутива (запасной вариант через lsb_release)
    CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    if [ -z "$CODENAME" ]; then
        CODENAME=$(lsb_release -cs)
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_substep "Обновление списка пакетов с учётом Docker..."
    nala update

    print_substep "Установка Docker и компонентов..."
    nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    print_success "Docker установлен: $(docker --version)"
fi

# ============================
#  7. Включение и запуск Docker
# ============================

print_header "Включение и запуск Docker"
systemctl enable --now docker
systemctl status docker --no-pager | head -5
print_success "Docker запущен"

# ============================
#  8. Добавление пользователя в группу docker
# ============================

if [ "$ORIGINAL_USER" != "root" ] && id "$ORIGINAL_USER" &>/dev/null; then
    print_substep "Добавление пользователя $ORIGINAL_USER в группу docker..."
    usermod -aG docker "$ORIGINAL_USER"
    print_success "Пользователь $ORIGINAL_USER добавлен в группу docker (перелогиньтесь, чтобы применить изменения)"
fi

# ============================
#  9. Итоговое резюме
# ============================

print_header "Установка завершена успешно!"

# Собираем информацию для красивого вывода
DOCKER_VER=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
COMPOSE_VER=$(docker compose version --short 2>/dev/null || echo "не установлен")
CURRENT_LOCALE=$(locale | grep LANG= | cut -d= -f2)
CURRENT_TIMEZONE=$(timedatectl show --property=Timezone --value)
DOCKER_DIR=$( [ -d "/opt/docker" ] && echo "создана" || echo "ОТСУТСТВУЕТ" )

# Создаём красивое резюме в рамке
summary_width=$(get_terminal_width)
summary_text=""
summary_text+="  Docker: $DOCKER_VER\n"
summary_text+="  Compose: $COMPOSE_VER\n"
summary_text+="  Локаль: $CURRENT_LOCALE\n"
summary_text+="  Время: $CURRENT_TIMEZONE\n"
summary_text+="  Пользователь в группе docker: $ORIGINAL_USER\n"
summary_text+="  Директория /opt/docker: $DOCKER_DIR"


# Выводим без дополнительной рамки, потому что print_header уже нарисовал верхнюю линию.
# Можно вывести простой блок с информацией.
echo -e "\033[1;37m$summary_text\033[0m"

print_success "Скрипт выполнен. Рекомендуется перезагрузить сервер."

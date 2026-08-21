#!/bin/bash
set -e

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами root (sudo)."
  exit 1
fi

#!/bin/bash

# Функция для печати заголовка в рамке из "="
print_header() {
    local text="$1"
    local cols=$(tput cols 2>/dev/null || echo 80)   # ширина терминала
    local text_len=${#text}
    local total_len=$cols                            # без внешних отступов

    # Вычисляем длину рамки с учётом двух пробелов (по одному с каждой стороны)
    local padding=$(( (total_len - text_len - 2) / 2 ))
    local remainder=$(( (total_len - text_len - 2) % 2 ))

    # Если текст слишком длинный – выводим без рамки
    if (( text_len + 2 > total_len )); then
        echo "$text"
        return
    fi

    # Делим "=" поровну, остаток отдаём левой части
    local left_padding=$((padding + remainder))
    local right_padding=$padding

    # Создаём строки из "=" нужной длины
    local left_line right_line
    printf -v left_line '%*s' "$left_padding" ''
    left_line=${left_line// /=}
    printf -v right_line '%*s' "$right_padding" ''
    right_line=${right_line// /=}

    # Вывод: рамка + пробел + текст + пробел + рамка (жирный синий)
    echo -e "\033[1;34m${left_line} ${text} ${right_line}\033[0m"
}

# Использование:
print_header "Обновление системы и установка nala"

# echo "=== Обновление системы и установка nala ==="
# apt update
# apt install -y nala

# echo "=== Обновление всех пакетов через nala ==="
# nala upgrade -y

# echo "=== Настройка локали (en_US.UTF-8) ==="
# DEBIAN_FRONTEND=noninteractive nala install -y locales
# echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
# locale-gen
# update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
# export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# echo "=== Установка часового пояса (Europe/Moscow) ==="
# timedatectl set-timezone Europe/Moscow

# echo "=== Установка базовых утилит ==="
# nala install -y sudo tree unzip tar gzip vim git htop curl wget \
#   apt-transport-https ca-certificates

# echo "=== Очистка кэша nala ==="
# nala clean

# echo "=== Проверка локали и времени ==="
# locale
# timedatectl

# echo "=== Установка Docker ==="
# nala install -y gnupg lsb-release
# mkdir -p /opt/docker/
# install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor > /etc/apt/keyrings/docker.gpg
# chmod a+r /etc/apt/keyrings/docker.gpg
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# nala update
# nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# echo "=== Проверка Docker ==="
# docker version

# echo "=== Включение и запуск Docker ==="
# systemctl enable --now docker
# systemctl status docker --no-pager

# echo "=== Готово! ==="

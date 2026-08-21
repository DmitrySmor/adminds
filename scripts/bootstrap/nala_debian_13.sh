#!/bin/bash
set -e

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами root (sudo)."
  exit 1
fi

apt update
apt install -y nala

# Обновление всех пакетов через nala
nala upgrade -y

# Настройка локали (en_US.UTF-8)
DEBIAN_FRONTEND=noninteractive nala install -y locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Установка часового пояса (Europe/Moscow)
timedatectl set-timezone Europe/Moscow

# Установка базовых утилит
nala install -y sudo tree unzip tar gzip vim git htop curl wget \
  apt-transport-https ca-certificates

# Очистка кэша nala
nala clean

# Проверка локали и времениd
locale
timedatectl

# Установка Docker
nala install -y gnupg lsb-release
mkdir -p /opt/docker/
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor > /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

nala update
nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Проверка Docker
docker version

# Включение и запуск Docker
systemctl enable --now docker
systemctl status docker --no-pager

echo "=== Готово! ==="

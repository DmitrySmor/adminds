#!/usr/bin/env bash
set -euo pipefail

# Отключаем интерактивные запросы
export DEBIAN_FRONTEND=noninteractive

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт нужно запускать с sudo или от root."
    exit 1
fi

echo "Обновление списка пакетов..."
apt-get update

echo "Апгрейд всех установленных пакетов..."
apt-get upgrade -y

echo "Очистка старых и неиспользуемых пакетов ..."
apt-get autoremove -y
apt-get autoclean

echo "Обновление пакетов завершено."

#!/usr/bin/env bash

set -euo pipefail

# Проверяем операционную систему.
if [[ ! -f /etc/os-release ]]; then
    printf 'Ошибка: файл /etc/os-release не найден\n' >&2
    exit 1
fi

# Загружаем информацию об операционной системе.
# shellcheck disable=SC1091
source /etc/os-release

if [[ "$ID" != "debian" ]]; then
    printf 'Ошибка: поддерживается только Debian\n' >&2
    exit 1
fi

if [[ "$VERSION_ID" != "13" ]]; then
    printf 'Ошибка: поддерживается только Debian 13, обнаружена версия %s\n' \
        "$VERSION_ID" >&2
    exit 1
fi

printf 'Операционная система: Debian %s\n' "$VERSION_ID"

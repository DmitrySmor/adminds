#!/usr/bin/env bash

# Завершаем скрипт при ошибке, использовании необъявленной переменной
# или ошибке внутри конвейера команд.
set -euo pipefail

# Получаем абсолютный путь к директории, в которой находится build.sh.
# Это позволяет запускать сборщик из любой директории.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Корень проекта находится на один уровень выше scripts/.
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Получаем имя workflow из первого аргумента командной строки.
# Если аргумент не передан, используем пустое значение.
WORKFLOW_NAME="${1:-}"

# Формируем путь к исходному workflow.
SOURCE_FILE="$PROJECT_DIR/scripts/src/workflows/${WORKFLOW_NAME}.sh"

# Определяем директорию, куда будут помещаться собранные скрипты.
BUILD_DIR="$PROJECT_DIR/build"

# Формируем полный путь к итоговому скрипту.
OUTPUT_FILE="$BUILD_DIR/${WORKFLOW_NAME}.sh"

# Проверяем, передал ли пользователь имя workflow.
if [[ -z "$WORKFLOW_NAME" ]]; then
    printf 'Ошибка: не указан workflow\n' >&2
    printf 'Использование: %s <workflow>\n' "$0" >&2
    exit 1
fi

# Проверяем, существует ли указанный исходный workflow.
if [[ ! -f "$SOURCE_FILE" ]]; then
    printf 'Ошибка: workflow не найден: %s\n' "$SOURCE_FILE" >&2
    exit 1
fi

# Создаём директорию для результатов сборки, если её ещё нет.
mkdir -p "$BUILD_DIR"

# На данном этапе сборщик просто копирует исходный workflow
# в директорию build.
#
# Позже здесь появится настоящая сборка:
# библиотеки + задачи + workflow -> один standalone Bash-скрипт.
cp "$SOURCE_FILE" "$OUTPUT_FILE"

# Делаем собранный скрипт исполняемым.
chmod +x "$OUTPUT_FILE"

# Сообщаем пользователю, где находится результат сборки.
printf 'Сборка завершена: %s\n' "$OUTPUT_FILE"

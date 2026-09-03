#!/usr/bin/env bash

set -euo pipefail

# Получаем абсолютный путь к директории, в которой находится build.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Корень проекта находится на один уровень выше scripts/.
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Получаем имя workflow из первого аргумента.
WORKFLOW_NAME="${1:-}"

# Определяем исходные файлы.
COLORS_FILE="$PROJECT_DIR/scripts/src/lib/colors.sh"
LOG_FILE="$PROJECT_DIR/scripts/src/lib/log.sh"
WORKFLOW_FILE="$PROJECT_DIR/scripts/src/workflows/${WORKFLOW_NAME}.sh"

# Определяем директорию и имя итогового файла.
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_FILE="$BUILD_DIR/${WORKFLOW_NAME}.sh"

# Проверяем наличие имени workflow.
if [[ -z "$WORKFLOW_NAME" ]]; then
    printf 'Ошибка: не указан workflow\n' >&2
    printf 'Использование: %s <workflow>\n' "$0" >&2
    exit 1
fi

# Проверяем наличие всех необходимых исходных файлов.
for file in "$COLORS_FILE" "$LOG_FILE" "$WORKFLOW_FILE"; do
    if [[ ! -f "$file" ]]; then
        printf 'Ошибка: файл не найден: %s\n' "$file" >&2
        exit 1
    fi
done

# Создаём директорию для результатов сборки.
mkdir -p "$BUILD_DIR"

# Выводит содержимое файла без shebang и set -euo pipefail.
#
# Это позволяет подключать библиотеки и workflow в итоговый скрипт,
# не дублируя заголовок и настройки Bash.
append_script_content() {
    local file="$1"

    sed \
        -e '/^#!\/usr\/bin\/env bash$/d' \
        -e '/^set -euo pipefail$/d' \
        "$file"
}

# Начинаем формирование итогового standalone-скрипта.
#
# Shebang и set -euo pipefail берём только из workflow.
# Из библиотек удаляем их shebang, чтобы внутри итогового файла
# оставался только один shebang.
{
    printf '#!/usr/bin/env bash\n\n'
    printf 'set -euo pipefail\n\n'

    printf '# === colors.sh ===\n\n'
    append_script_content "$COLORS_FILE"
    printf '\n'

    printf '# === log.sh ===\n\n'
    append_script_content "$LOG_FILE"
    printf '\n'

    printf '# === workflow: %s ===\n\n' "$WORKFLOW_NAME"
    append_script_content "$WORKFLOW_FILE"
} >"$OUTPUT_FILE"

# Делаем итоговый скрипт исполняемым.
chmod +x "$OUTPUT_FILE"

printf 'Сборка завершена: %s\n' "$OUTPUT_FILE"

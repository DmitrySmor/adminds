#!/usr/bin/env bash

set -euo pipefail

# Получаем абсолютный путь к директории, в которой находится build.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Корень проекта находится на один уровень выше scripts/.
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Получаем имя workflow из первого аргумента.
WORKFLOW_NAME="${1:-}"

# Определяем исходные директории.
LIB_DIR="$PROJECT_DIR/scripts/src/lib"
TASKS_DIR="$PROJECT_DIR/scripts/src/tasks"
WORKFLOWS_DIR="$PROJECT_DIR/scripts/src/workflows"

# Определяем исходный workflow.
WORKFLOW_FILE="$WORKFLOWS_DIR/${WORKFLOW_NAME}.sh"

# Определяем директорию и имя итогового файла.
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_FILE="$BUILD_DIR/${WORKFLOW_NAME}.sh"

# Статический список библиотек.
#
# Библиотеки являются общими для всех standalone-скриптов
# и подключаются в каждый workflow.
LIB_FILES=(
    "$LIB_DIR/colors.sh"
    "$LIB_DIR/log.sh"
)

# Проверяем наличие имени workflow.
if [[ -z "$WORKFLOW_NAME" ]]; then
    printf 'Ошибка: не указан workflow\n' >&2
    printf 'Использование: %s <workflow>\n' "$0" >&2
    exit 1
fi

# Проверяем наличие workflow.
if [[ ! -f "$WORKFLOW_FILE" ]]; then
    printf 'Ошибка: workflow не найден: %s\n' "$WORKFLOW_FILE" >&2
    exit 1
fi

# Проверяем наличие директорий с исходными файлами.
for directory in \
    "$LIB_DIR" \
    "$TASKS_DIR" \
    "$WORKFLOWS_DIR"; do

    if [[ ! -d "$directory" ]]; then
        printf 'Ошибка: директория не найдена: %s\n' "$directory" >&2
        exit 1
    fi
done

# Проверяем наличие библиотек.
for file in "${LIB_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        printf 'Ошибка: библиотека не найдена: %s\n' "$file" >&2
        exit 1
    fi
done

# Получаем список tasks.
mapfile -t TASK_FILES < <(
    find "$TASKS_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.sh' \
        -print |
        sort
)

# Проверяем наличие tasks.
if [[ "${#TASK_FILES[@]}" -eq 0 ]]; then
    printf 'Ошибка: tasks не найдены: %s\n' "$TASKS_DIR" >&2
    exit 1
fi

# Проверяем Bash-синтаксис исходных файлов.
for file in "${LIB_FILES[@]}" "${TASK_FILES[@]}" "$WORKFLOW_FILE"; do
    if ! bash -n "$file"; then
        printf 'Ошибка: некорректный Bash-синтаксис: %s\n' "$file" >&2
        exit 1
    fi
done

# Создаём реестр функций tasks.
#
# Формат:
#
# TASK_FUNCTIONS["имя_функции"]="путь_к_task"
#
# Например:
#
# TASK_FUNCTIONS["get_base_packages"]=".../tasks/base_packages.sh"
declare -A TASK_FUNCTIONS=()

for file in "${TASK_FILES[@]}"; do
    while IFS= read -r function_name; do
        if [[ -n "${TASK_FUNCTIONS[$function_name]:-}" ]]; then
            printf \
                'Ошибка: функция "%s" определена более чем в одном task:\n' \
                "$function_name" \
                >&2

            printf '  %s\n' "${TASK_FUNCTIONS[$function_name]}" >&2
            printf '  %s\n' "$file" >&2

            exit 1
        fi

        TASK_FUNCTIONS["$function_name"]="$file"
    done < <(
        sed -nE \
            's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)[[:space:]]*\{.*$/\2/p' \
            "$file"
    )
done

# Определяем tasks, используемые workflow.
#
# Workflow является источником истины:
# task попадает в итоговый скрипт только в том случае,
# если его функция вызывается непосредственно в workflow.
declare -A USED_TASKS=()

while IFS= read -r line; do
    # Убираем начальные пробелы.
    line="${line#"${line%%[![:space:]]*}"}"

    # Пропускаем пустые строки.
    [[ -z "$line" ]] && continue

    # Пропускаем комментарии.
    [[ "$line" == \#* ]] && continue

    # Пропускаем присваивания переменных и массивов.
    #
    # Например:
    #
    # BASE_PACKAGES=(
    # DOCKER_PACKAGES=(
    [[ "$line" == *=* ]] && continue

    # Получаем первое слово строки.
    read -r function_name _ <<<"$line"

    # Убираем () у вызова вида:
    #
    # function_name()
    function_name="${function_name%\(\)}"

    # Если функция является task,
    # добавляем соответствующий файл в сборку.
    if [[ -n "${TASK_FUNCTIONS[$function_name]:-}" ]]; then
        USED_TASKS["${TASK_FUNCTIONS[$function_name]}"]=1
    fi

done <"$WORKFLOW_FILE"

# Формируем список используемых tasks
# в стабильном порядке.
USED_TASK_FILES=()

for file in "${TASK_FILES[@]}"; do
    if [[ -n "${USED_TASKS[$file]:-}" ]]; then
        USED_TASK_FILES+=("$file")
    fi
done

# Создаём директорию для результатов сборки.
mkdir -p "$BUILD_DIR"

# Выводит содержимое файла без shebang и set -euo pipefail.
#
# Это позволяет объединять несколько Bash-файлов
# в один standalone-скрипт.
append_script_content() {
    local file="$1"

    sed \
        -e '/^#!\/usr\/bin\/env bash$/d' \
        -e '/^set -euo pipefail$/d' \
        "$file"
}

# Начинаем формирование итогового standalone-скрипта.
#
# Порядок:
# 1. shebang и настройки Bash;
# 2. библиотеки;
# 3. используемые tasks;
# 4. выбранный workflow.
{
    printf '#!/usr/bin/env bash\n\n'
    printf 'set -euo pipefail\n\n'

    # Подключаем все библиотеки.
    for file in "${LIB_FILES[@]}"; do
        append_script_content "$file"
        printf '\n'
    done

    # Подключаем только tasks,
    # используемые workflow.
    for file in "${USED_TASK_FILES[@]}"; do
        append_script_content "$file"
        printf '\n'
    done

    # Подключаем workflow.
    append_script_content "$WORKFLOW_FILE"
} >"$OUTPUT_FILE"

# Удаляет из итогового скрипта неиспользуемые readonly-переменные,
# обнаруженные ShellCheck с предупреждением SC2034.
#
# Исходные файлы не изменяются.
# Оптимизируется только итоговый файл сборки.
remove_unused_readonly_variables() {
    local shellcheck_output
    local line_number
    local variable_name
    local declaration
    local lines_to_remove=()

    if ! command -v shellcheck >/dev/null 2>&1; then
        return
    fi

    shellcheck_output="$(
        shellcheck \
            -f gcc \
            "$OUTPUT_FILE" \
            2>/dev/null || true
    )"

    while IFS=: read -r _ line_number _ message; do
        if [[ "$message" != *"[SC2034]"* ]]; then
            continue
        fi

        variable_name="$(
            printf '%s\n' "$message" |
                sed -n 's/.*warning: \([^ ]*\) appears unused.*/\1/p'
        )"

        if [[ -z "$variable_name" ]]; then
            continue
        fi

        declaration="$(
            sed -n "${line_number}p" "$OUTPUT_FILE"
        )"

        if [[ "$declaration" =~ ^[[:space:]]*readonly[[:space:]]+$variable_name= ]]; then
            lines_to_remove+=("$line_number")
        fi
    done <<<"$shellcheck_output"

    if [[ "${#lines_to_remove[@]}" -eq 0 ]]; then
        return
    fi

    for line_number in $(
        printf '%s\n' "${lines_to_remove[@]}" |
            sort -rn
    ); do
        sed -i "${line_number}d" "$OUTPUT_FILE"
    done
}

# Удаляем неиспользуемые readonly-переменные
# из итогового скрипта.
remove_unused_readonly_variables

# Форматируем итоговый Bash-скрипт, если shfmt установлен.
if command -v shfmt >/dev/null 2>&1; then
    shfmt -w "$OUTPUT_FILE"
fi

# Делаем итоговый скрипт исполняемым.
chmod +x "$OUTPUT_FILE"

printf '\n'
printf 'Сборка завершена:\n'
printf '  Workflow: %s\n' "$WORKFLOW_NAME"
printf '  Tasks:    %s\n' "${#USED_TASK_FILES[@]}"
printf '  Output:   %s\n' "$OUTPUT_FILE"

printf '\n'
printf 'Подключённые tasks:\n'

for file in "${USED_TASK_FILES[@]}"; do
    printf '  - %s\n' "$(basename "$file")"
done

printf '\n'
printf 'Запуск на сервере:\n'
printf 'curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/main/build/%s.sh | sudo bash\n' \
    "$WORKFLOW_NAME"

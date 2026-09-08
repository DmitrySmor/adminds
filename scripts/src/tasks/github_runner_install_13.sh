#!/usr/bin/env bash

set -euo pipefail

# ============================
#  Установка GitHub Actions Runner
# ============================
# Создаёт пользователя github-runner,
# получает последнюю версию GitHub Actions Runner,
# скачивает и устанавливает Runner,
# запрашивает URL репозитория и registration token,
# регистрирует Runner и запускает его как systemd service.
#
# Runner получает имя:
# github-runner-<repository>

github_runner_install() {
    local RUNNER_USER="github-runner"
    local RUNNER_HOME="/home/${RUNNER_USER}"
    local RUNNER_DIR="${RUNNER_HOME}/actions-runner"

    local REPOSITORY_URL=""
    local REPOSITORY_NAME=""
    local REGISTRATION_TOKEN=""

    local RUNNER_NAME=""
    local RUNNER_VERSION=""
    local RUNNER_ARCH=""
    local RUNNER_PACKAGE=""
    local RUNNER_URL=""
    local RUNNER_ARCHIVE="/tmp/github-actions-runner.tar.gz"

    # Проверка зависимостей
    log_step "Проверка зависимостей..."

    for command in curl tar jq; do
        if ! command -v "$command" >/dev/null 2>&1; then
            log_error "Необходимая команда не найдена: ${command}"
            exit 1
        fi
    done

    log_success "Зависимости проверены"

    # Создание пользователя
    log_step "Создание пользователя ${RUNNER_USER}..."

    if id "$RUNNER_USER" >/dev/null 2>&1; then
        log_success "Пользователь ${RUNNER_USER} уже существует"
    else
        useradd \
            --create-home \
            --home-dir "$RUNNER_HOME" \
            --shell /bin/bash \
            --comment "" \
            "$RUNNER_USER"

        log_success "Пользователь ${RUNNER_USER} создан"
    fi

    # Определение архитектуры
    log_step "Определение архитектуры..."

    case "$(uname -m)" in
    x86_64)
        RUNNER_ARCH="x64"
        ;;

    aarch64)
        RUNNER_ARCH="arm64"
        ;;

    *)
        log_error "Неподдерживаемая архитектура: $(uname -m)"
        exit 1
        ;;
    esac

    log_success "Архитектура: ${RUNNER_ARCH}"

    # Получение последней версии Runner
    log_step "Получение последней версии actions/runner..."

    RUNNER_VERSION="$(
        curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --header "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/actions/runner/releases/latest" |
            jq -r '.tag_name'
    )"

    if [[ -z "$RUNNER_VERSION" || "$RUNNER_VERSION" == "null" ]]; then
        log_error "Не удалось получить последнюю версию actions/runner"
        exit 1
    fi

    log_success "Последняя версия: ${RUNNER_VERSION}"

    # Формирование URL Runner
    RUNNER_PACKAGE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION#v}.tar.gz"

    RUNNER_URL="https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/${RUNNER_PACKAGE}"

    # Получение URL репозитория
    printf '\n'
    printf 'GitHub repository URL\n'
    printf 'Пример: https://github.com/DmitrySmor/ansibleds\n'
    printf 'URL: '

    read -r REPOSITORY_URL

    if [[ -z "$REPOSITORY_URL" ]]; then
        log_error "URL репозитория не может быть пустым"
        exit 1
    fi

    # Удаление завершающего /
    REPOSITORY_URL="${REPOSITORY_URL%/}"

    # Определение имени репозитория
    REPOSITORY_NAME="${REPOSITORY_URL##*/}"
    REPOSITORY_NAME="${REPOSITORY_NAME%.git}"

    if [[ -z "$REPOSITORY_NAME" ]]; then
        log_error "Не удалось определить имя репозитория"
        exit 1
    fi

    RUNNER_NAME="github-runner-${REPOSITORY_NAME}"

    log_success "Репозиторий: ${REPOSITORY_NAME}"
    log_success "Имя Runner: ${RUNNER_NAME}"

    # Получение registration token
    printf '\n'
    printf 'GitHub Actions Runner registration token\n'
    printf 'Token: '

    read -rs REGISTRATION_TOKEN
    printf '\n'

    if [[ -z "$REGISTRATION_TOKEN" ]]; then
        log_error "Registration token не может быть пустым"
        exit 1
    fi

    # Подготовка директории Runner
    log_step "Подготовка GitHub Actions Runner..."

    mkdir -p "$RUNNER_DIR"

    find \
        "$RUNNER_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf {} +

    # Скачивание Runner
    log_step "Скачивание ${RUNNER_PACKAGE}..."

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --output "$RUNNER_ARCHIVE" \
        "$RUNNER_URL"

    log_success "Runner скачан"

    # Распаковка Runner
    log_step "Распаковка GitHub Actions Runner..."

    tar \
        --extract \
        --gzip \
        --file "$RUNNER_ARCHIVE" \
        --directory "$RUNNER_DIR"

    rm -f "$RUNNER_ARCHIVE"

    log_success "Runner распакован"

    # Установка зависимостей Runner
    log_step "Установка зависимостей GitHub Actions Runner..."

    "$RUNNER_DIR/bin/installdependencies.sh"

    log_success "Зависимости Runner установлены"

    # Установка владельца
    log_step "Настройка владельца файлов Runner..."

    chown \
        --recursive \
        "${RUNNER_USER}:${RUNNER_USER}" \
        "$RUNNER_DIR"

    log_success "Права доступа настроены"

    # Регистрация Runner
    log_step "Регистрация GitHub Actions Runner..."

    runuser \
        --user "$RUNNER_USER" \
        --command "
            cd '$RUNNER_DIR' &&
            ./config.sh \
                --unattended \
                --url '$REPOSITORY_URL' \
                --token '$REGISTRATION_TOKEN' \
                --name '$RUNNER_NAME' \
                --labels 'self-hosted,linux,${RUNNER_ARCH},ansible' \
                --replace
        "

    unset REGISTRATION_TOKEN

    log_success "Runner зарегистрирован"

    # Установка systemd service
    log_step "Установка systemd service..."

    "$RUNNER_DIR/svc.sh" install "$RUNNER_USER"

    log_success "Systemd service установлен"

    # Запуск Runner
    log_step "Запуск GitHub Actions Runner..."

    "$RUNNER_DIR/svc.sh" start

    log_success "GitHub Actions Runner запущен"

    # Проверка Runner
    log_step "Проверка состояния Runner..."

    "$RUNNER_DIR/svc.sh" status

    log_success "GitHub Actions Runner успешно установлен"

    # Информация
    printf '\n'
    log_success "Информация о Runner:"
    printf '  User:       %s\n' "$RUNNER_USER"
    printf '  Name:       %s\n' "$RUNNER_NAME"
    printf '  Repository: %s\n' "$REPOSITORY_URL"
    printf '  Version:    %s\n' "$RUNNER_VERSION"
    printf '  Directory:  %s\n' "$RUNNER_DIR"
    printf '  Labels:     self-hosted, linux, %s, ansible\n' "$RUNNER_ARCH"
}

#!/bin/bash
# install-hawser-edge.sh — установка Hawser-агента в Edge Mode (только для root)

set -euo pipefail

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
    echo "❌ Этот скрипт должен запускаться от root (или через sudo)."
    exit 1
fi

# Запрос токена (обязательный параметр)
while true; do
    read -rp "Введите токен агента (из Dockhand): " HAWSER_TOKEN
    if [[ -n "$HAWSER_TOKEN" ]]; then
        break
    else
        echo "❌ Токен не может быть пустым. Попробуйте снова."
    fi
done

if [[ -z "${DOCKHAND_DOMAIN:-}" ]]; then
    exec < /dev/tty
    read -rp "Введите доменное имя сервера Dockhand [dockhand.energo-effect.pro]: " DOCKHAND_DOMAIN
    DOCKHAND_DOMAIN="${DOCKHAND_DOMAIN:-dockhand.energo-effect.pro}"
else
    echo "→ Используется домен из переменной окружения DOCKHAND_DOMAIN"
fi

DOCKHAND_SERVER_URL="wss://${DOCKHAND_DOMAIN}/api/hawser/connect"

echo "→ Установка Hawser Edge с параметрами:"
echo "  DOCKHAND_SERVER_URL = $DOCKHAND_SERVER_URL"
echo "  TOKEN               = ********"

# --- Определение ОС и архитектуры ---
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)   ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armv7|arm) ARCH="arm" ;;
    *)
        echo "❌ Неподдерживаемая архитектура: $ARCH"
        exit 1
        ;;
esac

# --- Получение последней версии через GitHub API ---
echo "→ Определение последней версии Hawser..."
LATEST_VERSION=$(curl -fsSL "https://api.github.com/repos/Finsys/hawser/releases/latest" | grep '"tag_name"' | sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/')
if [[ -z "$LATEST_VERSION" ]]; then
    echo "❌ Не удалось получить последнюю версию с GitHub."
    exit 1
fi
echo "  Последняя версия: $LATEST_VERSION"

# --- Формирование URL скачивания ---
DOWNLOAD_URL="https://github.com/Finsys/hawser/releases/download/v${LATEST_VERSION}/hawser_${LATEST_VERSION}_${OS}_${ARCH}.tar.gz"
echo "→ Загрузка из: $DOWNLOAD_URL"

# --- Временная директория ---
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# --- Скачивание и распаковка ---
echo "→ Скачивание бинарного файла..."
if ! curl -fsSL -o "$TMP_DIR/hawser.tar.gz" "$DOWNLOAD_URL"; then
    echo "❌ Ошибка загрузки. Проверьте доступность релиза."
    exit 1
fi

echo "→ Распаковка..."
tar -xzf "$TMP_DIR/hawser.tar.gz" -C "$TMP_DIR"

# --- Установка бинарника ---
echo "→ Установка /usr/local/bin/hawser ..."
install -m 755 "$TMP_DIR/hawser" /usr/local/bin/hawser

# --- Подготовка каталога стеков ---
echo "→ Создание /opt/docker (если отсутствует)..."
mkdir -p /opt/docker

echo "→ Скрипт остановлен на этапе проверки версии"
exit 1

# --- Конфигурационный файл ---
echo "→ Создание /etc/hawser/config ..."
mkdir -p /etc/hawser
cat > /etc/hawser/config <<EOF
# Edge Mode — соединение по WebSocket
DOCKHAND_SERVER_URL=${DOCKHAND_SERVER_URL}
TOKEN=${HAWSER_TOKEN}

STACKS_DIR=/opt/docker
DOCKER_SOCKET=/var/run/docker.sock
EOF

chmod 600 /etc/hawser/config

# --- Systemd-сервис ---
echo "→ Создание /etc/systemd/system/hawser.service ..."
cat > /etc/systemd/system/hawser.service <<'EOF'
[Unit]
Description=Hawser Agent (Edge Mode) for Dockhand
Documentation=https://github.com/Finsys/hawser
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hawser
Restart=always
RestartSec=10
EnvironmentFile=/etc/hawser/config

NoNewPrivileges=false
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/run/docker.sock /opt/docker /etc/hawser

[Install]
WantedBy=multi-user.target
EOF

# --- Запуск сервиса ---
echo "→ Запуск hawser.service..."
systemctl daemon-reload
systemctl enable --now hawser

# --- Проверка статуса ---
echo "→ Статус сервиса:"
systemctl status hawser --no-pager || true

echo ""
echo "✅ Установка завершена!"
echo "Для просмотра логов: journalctl -u hawser -f"

#!/bin/bash
# install-hawser-edge.sh — установка Hawser-агента в Edge Mode (только для root)

set -euo pipefail

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
    echo "❌ Этот скрипт должен запускаться от root (или через sudo)."
    exit 1
fi

# --- Запрос параметров с проверками ---
while true; do
    read -rp "Введите токен агента (из Dockhand): " HAWSER_TOKEN
    if [[ -n "$HAWSER_TOKEN" ]]; then
        break
    else
        echo "❌ Токен не может быть пустым. Попробуйте снова."
    fi
done

read -rp "Введите доменное имя сервера Dockhand [dockhand.energo-effect.pro]: " DOCKHAND_DOMAIN
DOCKHAND_DOMAIN="${DOCKHAND_DOMAIN:-dockhand.energo-effect.pro}"

DOCKHAND_SERVER_URL="wss://${DOCKHAND_DOMAIN}/api/hawser/connect"

echo "→ Установка Hawser Edge с параметрами:"
echo "  DOCKHAND_SERVER_URL = $DOCKHAND_SERVER_URL"
echo "  TOKEN               = ********"

# --- Временная директория для загрузки ---
TMP_DIR="/tmp/hawser-install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# --- Скачивание последней версии бинарника с проверкой ---
echo "→ Загрузка бинарного файла Hawser в $TMP_DIR ..."
if ! curl -fsSL -o hawser.tar.gz \
    "https://github.com/Finsys/hawser/releases/latest/download/hawser_linux_amd64.tar.gz"; then
    echo "❌ Ошибка загрузки: возможно, релиз не найден или имя файла неверное."
    echo "   Проверьте https://github.com/Finsys/hawser/releases/latest"
    exit 1
fi

echo "→ Распаковка..."
tar -xzf hawser.tar.gz

# --- Установка бинарника (перезапись, если существует) ---
echo "→ Установка /usr/local/bin/hawser ..."
install -m 755 hawser /usr/local/bin/hawser

# Очистка временной директории
cd / && rm -rf "$TMP_DIR"

# --- Подготовка каталога стеков (только создание, без изменения прав) ---
echo "→ Создание /opt/docker (если отсутствует)..."
mkdir -p /opt/docker

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

# --- Systemd-сервис (без создания пользователя, от root) ---
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

# Без ограничений — работаем от root
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

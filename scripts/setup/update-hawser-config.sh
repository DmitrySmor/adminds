#!/bin/bash
# update-hawser-config.sh — обновление токена и/или домена для Hawser-агента

set -euo pipefail

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
    echo "❌ Этот скрипт должен запускаться от root (или через sudo)."
    exit 1
fi

# --- Проверка наличия конфигурационного файла ---
CONFIG_FILE="/etc/hawser/config"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Конфигурационный файл не найден: $CONFIG_FILE"
    echo "   Убедитесь, что агент установлен."
    exit 1
fi

# --- Функция для безопасного чтения из терминала ---
read_from_tty() {
    local prompt="$1"
    local var_name="$2"
    local current_value="$3"
    local input

    echo ""
    echo "Текущее значение: $current_value"
    read -rp "$prompt" input < /dev/tty

    if [[ -n "$input" ]]; then
        eval "$var_name=\"$input\""
        return 0
    else
        eval "$var_name=\"$current_value\""
        echo "→ Значение сохранено без изменений."
        return 0
    fi
}

# --- Чтение текущих значений из конфига ---
CURRENT_TOKEN=$(grep "^TOKEN=" "$CONFIG_FILE" | cut -d'=' -f2-)
CURRENT_URL=$(grep "^DOCKHAND_SERVER_URL=" "$CONFIG_FILE" | cut -d'=' -f2-)
CURRENT_DOMAIN=$(echo "$CURRENT_URL" | sed -E 's#wss://([^/]+)/.*#\1#')

echo "════════════════════════════════════════════════════════"
echo "   🔄 ОБНОВЛЕНИЕ КОНФИГУРАЦИИ HAWSER АГЕНТА"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Текущая конфигурация:"
echo "  • Сервер: $CURRENT_DOMAIN"
echo "  • Токен:  ${CURRENT_TOKEN:0:10}...${CURRENT_TOKEN: -4}"

# --- Обновление токена ---
echo ""
echo "────────────────────────────────────────────────────────"
echo "1️⃣ ОБНОВЛЕНИЕ ТОКЕНА"
echo "────────────────────────────────────────────────────────"
read_from_tty "Введите новый токен (или Enter для сохранения текущего): " NEW_TOKEN "$CURRENT_TOKEN"

# --- Обновление домена ---
echo ""
echo "────────────────────────────────────────────────────────"
echo "2️⃣ ОБНОВЛЕНИЕ ДОМЕНА"
echo "────────────────────────────────────────────────────────"
read_from_tty "Введите новый домен (или Enter для сохранения текущего): " NEW_DOMAIN "$CURRENT_DOMAIN"

# --- Формирование нового URL ---
NEW_URL="wss://${NEW_DOMAIN}/api/hawser/connect"

# --- Проверка, были ли изменения ---
if [[ "$NEW_TOKEN" == "$CURRENT_TOKEN" && "$NEW_URL" == "$CURRENT_URL" ]]; then
    echo ""
    echo "ℹ️ Изменений не обнаружено. Конфигурация осталась прежней."
    exit 0
fi

# --- Создание резервной копии ---
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo ""
echo "✅ Создана резервная копия: $BACKUP_FILE"

# --- Обновление конфигурации ---
echo "→ Обновление конфигурационного файла..."

# Создаем новый конфиг с обновленными значениями
cat > "$CONFIG_FILE" <<EOF
# Edge Mode — соединение по WebSocket
DOCKHAND_SERVER_URL=${NEW_URL}
TOKEN=${NEW_TOKEN}

STACKS_DIR=/opt/docker
DOCKER_SOCKET=/var/run/docker.sock
EOF

chmod 600 "$CONFIG_FILE"

# --- Перезапуск сервиса ---
echo "→ Перезапуск hawser.service..."
systemctl restart hawser

# --- Проверка статуса ---
sleep 2
echo ""
echo "→ Статус сервиса:"
systemctl status hawser --no-pager || true

# --- Проверка логов на ошибки ---
echo ""
echo "→ Последние логи (проверка ошибок):"
journalctl -u hawser -n 10 --no-pager | grep -i "error\|fail\|warn" || echo "   ✅ Ошибок не обнаружено."

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНО"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Новая конфигурация:"
echo "  • Сервер: $NEW_DOMAIN"
echo "  • Токен:  ${NEW_TOKEN:0:10}...${NEW_TOKEN: -4}"
echo ""
echo "Резервная копия сохранена: $BACKUP_FILE"
echo ""
echo "Для просмотра полных логов: journalctl -u hawser -f"

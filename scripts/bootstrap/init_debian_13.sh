#!/usr/bin/env bash
# shellcheck disable=SC1008
set -euo pipefail

# Цветной вывод
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

# Функции логирования
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

error() {
    log_error "$*"
    exit 1
}

# Проверка прав
if [[ $EUID -ne 0 ]]; then
    error "Этот скрипт должен запускаться от root (используйте sudo)"
fi

# Проверка наличия apt-get
command -v apt-get >/dev/null 2>&1 || error "apt-get не найден. Это не Debian/Ubuntu система"

# Отключаем интерактивные запросы
export DEBIAN_FRONTEND=noninteractive

# Блокировка параллельных запусков apt (для безопасности)
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    log_warn "Ожидание освобождения блокировки dpkg..."
    sleep 5
done

log_info "=== НАЧАЛО ОБНОВЛЕНИЯ СИСТЕМЫ ==="

log_info "Обновление списка пакетов..."
apt-get update

log_info "Апгрейд пакетов..."
apt-get upgrade -y

log_info "Дистрибутивный апгрейд..."
apt-get dist-upgrade -y

log_info "Очистка кэша..."
apt-get autoclean -y
apt-get clean

log_info "Удаление неиспользуемых пакетов..."
# Безопасный autoremove (с предупреждением)
AUTOREMOVE_OUTPUT=$(apt-get autoremove --dry-run 2>&1)
if echo "$AUTOREMOVE_OUTPUT" | grep -q "The following packages will be REMOVED:"; then
    log_warn "Будут удалены пакеты. Просмотр через 10 секунд..."
    echo "$AUTOREMOVE_OUTPUT" | grep -A 50 "The following packages will be REMOVED:" || true
    sleep 10
    apt-get autoremove -y
else
    log_info "Нет неиспользуемых пакетов для удаления"
fi

log_info "=== ОБНОВЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО ==="

# Показать информацию о системе
echo -e "\n${BLUE}Информация о системе после обновления:${NC}"
echo "----------------------------------------"
lsb_release -a 2>/dev/null || cat /etc/debian_version 2>/dev/null || true
uname -a
echo "----------------------------------------"

# Проверить необходимость перезагрузки
if [ -f /var/run/reboot-required ]; then
    log_warn "Требуется перезагрузка системы!"
    echo "Причина: $(cat /var/run/reboot-required 2>/dev/null || echo 'обновление ядра или системных библиотек')"
fi

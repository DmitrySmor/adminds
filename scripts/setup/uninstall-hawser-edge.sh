#!/bin/bash
# uninstall-hawser-edge.sh — полное удаление Hawser-агента

set -euo pipefail

echo "→ Остановка и отключение hawser.service..."
systemctl stop hawser 2>/dev/null || true
systemctl disable hawser 2>/dev/null || true

echo "→ Удаление файла сервиса..."
rm -f /etc/systemd/system/hawser.service
systemctl daemon-reload

echo "→ Удаление бинарного файла..."
rm -f /usr/local/bin/hawser

echo "→ Удаление конфигурации..."
rm -rf /etc/hawser

echo ""
echo "✅ Удаление завершено!"
echo "Каталог /opt/docker не был затронут — ваши стеки сохранены."

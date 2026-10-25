#!/usr/bin/env bash

INTERVAL=5
LOG_FILE="monitor.log"

echo "Мониторинг запущен. Интервал: ${INTERVAL}s. Лог: ${LOG_FILE}"
echo "Остановка: Ctrl+C"

while true; do
    {
        echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        echo "== free -h =="
        free -h
        echo ""
        echo "== df -h =="
        df -h
        echo ""
        echo "== uptime =="
        uptime
        echo
    } | tee -a "$LOG_FILE"
    sleep "$INTERVAL"
done

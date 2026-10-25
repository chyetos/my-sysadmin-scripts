#!/usr/bin/env bash

INTERVAL=30
LOG_FILE="monitor.log"

while true; do
    {
        echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        free -h
        df -h
        uptime
        echo
    } >> "$LOG_FILE"
    sleep "$INTERVAL"
done

#!/bin/bash
##############################################################
# АВТОМАТИЧЕСКОЕ ОБСЛУЖИВАНИЕ СИСТЕМЫ (ПОЛНЫЙ АВТОРЕЖИМ)
#
# + Мониторинг температуры (CPU / системы)
# + Мониторинг загрузки CPU и свободной RAM
# + Контроль свободного места на диске
#
# + Автоматическое обнаружение системных ошибок (journalctl)
# + Автоматическое исправление ошибок ОС, где это возможно
# + Автоматический перезапуск упавших системных сервисов
#
# + Мониторинг SSH-взломов (Failed password)
# + Автоматическая отправка уведомлений админу на почту
#
# + Контроль runaway процессов (CPU > 80%)
# + Контроль zombie процессов (Z-state)
# + Автоматическое завершение runaway-процессов
#
# + Автоматическое обновление системы (apt update + upgrade)
# + Очистка системы (autoremove, autoclean)
#
# + Ротация журналов каждые 2 дня
# + Автоматическая установка почтовой подсистемы (mailutils)
#
# + Полностью автономный режим — человек ничего не делает
# + Ежедневный запуск через systemd timer (00:00)
##############################################################


##############################################################
# АВТОМАТИЧЕСКОЕ ОБСЛУЖИВАНИЕ СИСТЕМЫ (ПОЛНЫЙ АВТОРЕЖИМ)
##############################################################

# ADMIN_EMAIL="sanichxxxx@mail.ru"   # ⛔ ОТКЛЮЧЕНО — почта не используется
LOG_FILE="/var/log/system_maintenance.log"
MIN_FREE_GB=10

log(){ echo "$(date '+%F %T') — $1" >> "$LOG_FILE"; }

rotate_logs(){
    MARK="/var/log/system_maintenance_last_rotate"
    [[ ! -f "$MARK" ]] && date +%s > "$MARK" && return
    NOW=$(date +%s)
    LAST=$(cat "$MARK")
    if (( NOW - LAST > 172800 )); then
        echo "===== ЛОГ СБРОШЕН =====" > "$LOG_FILE"
        date +%s > "$MARK"
    fi
}

#send_email(){ echo "$2" | mail -s "$1" "$ADMIN_EMAIL"; }   # ⛔ ОТКЛЮЧЕНО

check_disk(){
    FREE=$(df -BG / | awk 'NR==2{gsub("G","",$4); print $4}')
    log "Свободно: $FREE ГБ"

    # ((FREE < MIN_FREE_GB)) && send_email "Мало места!" "Свободно $FREE ГБ"    # ⛔ ОТКЛЮЧЕНО
}

monitor_memory_cpu(){
    CPU=$(uptime | awk -F"average:" '{print $2}')
    RAM=$(free -m | awk '/Mem:/ {print $4}')
    log "CPU load: $CPU"
    log "RAM free: $RAM MB"
}

monitor_temperature(){
    if command -v sensors >/dev/null; then
        log "Температура:"
        sensors >> "$LOG_FILE"
    else
        log "sensors не установлен"
    fi
}

check_journal_errors(){
    ERR=$(journalctl --since "24h" | grep -Ei "error|fail|panic")
    if [[ -n "$ERR" ]]; then
        log "Ошибки:"
        log "$ERR"
        # send_email "Ошибки системы" "$ERR"    # ⛔ ОТКЛЮЧЕНО
    else
        log "Ошибок нет"
    fi
}

check_services(){
    BAD=$(systemctl --failed --no-legend)
    if [[ -n "$BAD" ]]; then
        log "Упавшие сервисы:"
        log "$BAD"
        echo "$BAD" | awk '{print $1}' | while read S; do
            systemctl restart "$S"
            log "Перезапущен: $S"
        done
        # send_email "Упавшие сервисы" "$BAD"    # ⛔ ОТКЛЮЧЕНО
    else
        log "Все сервисы работают"
    fi
}

monitor_ssh(){
    ATT=$(journalctl -u ssh --since "24h" | grep "Failed password" | awk '{print $(NF-3)}' | sort | uniq -c)
    if [[ -n "$ATT" ]]; then
        log "Попытки взлома:"
        log "$ATT"
        # send_email "SSH атаки" "$ATT"   # ⛔ ОТКЛЮЧЕНО
    else
        log "Атак SSH нет"
    fi
}

monitor_processes(){
    Z=$(ps aux | awk '$8=="Z"')
    if [[ -n "$Z" ]]; then
        log "Zombie:"
        log "$Z"
        # send_email "Zombie" "$Z"   # ⛔ ОТКЛЮЧЕНО
    fi

    R=$(ps aux --sort=-%cpu | awk '$3>80')
    if [[ -n "$R" ]]; then
        log "Runaway:"
        log "$R"

        echo "$R" | awk '{print $2}' | while read PID; do
            kill -15 "$PID"
            sleep 1
            kill -0 "$PID" 2>/dev/null && kill -9 "$PID"
            log "Процесс $PID убит"
        done

        # send_email "Runaway" "$R"   # ⛔ ОТКЛЮЧЕНО
    fi
}

update_system(){
    log "Обновление..."
    apt update -y >> "$LOG_FILE"
    apt upgrade -y >> "$LOG_FILE"
    apt full-upgrade -y >> "$LOG_FILE"
    apt autoremove -y >> "$LOG_FILE"
    apt autoclean -y >> "$LOG_FILE"
    log "Готово."
}

rotate_logs
log "===== ЗАПУСК ====="

monitor_temperature
monitor_memory_cpu
check_disk
check_journal_errors
check_services
monitor_ssh
monitor_processes
update_system

log "===== ЗАВЕРШЕНО ====="

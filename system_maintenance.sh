#!/bin/bash

##############################################################
# АВТОМАТИЧЕСКОЕ ОБСЛУЖИВАНИЕ СИСТЕМЫ
# + Мониторинг температуры
# + Мониторинг CPU, RAM
# + Мониторинг диска
# + Проверка системных ошибок
# + Проверка сервисов
# + Обновления
# + Мониторинг SSH-взломов
# + Контроль runaway / zombie процессов
##############################################################

ADMIN_EMAIL="admin@example.com"
LOG_FILE="/var/log/system_maintenance.log"
MIN_FREE_GB=10
##############################################################


##########################
# ПИСАТЬ В ЛОГ
##########################
log() { echo "$(date "+%F %T") — $1" >> "$LOG_FILE"; }


##########################
# РОТАЦИЯ ЛОГОВ (каждые 2 дня)
##########################
rotate_logs() {
    ROTATE_MARK="/var/log/system_maintenance_last_rotate"

    [[ ! -f "$ROTATE_MARK" ]] && date +%s > "$ROTATE_MARK" && return

    LAST=$(cat "$ROTATE_MARK")
    NOW=$(date +%s)

    if (( NOW - LAST > 172800 )); then
        echo "===== ЛОГ ПЕРЕЗАПИСАН =====" > "$LOG_FILE"
        date +%s > "$ROTATE_MARK"
    fi
}


##########################
# ПОЧТА АДМИНУ
##########################
send_email() { echo "$2" | mail -s "$1" "$ADMIN_EMAIL"; }


##########################
# ПРОВЕРКА ДИСКА
##########################
check_disk() {
    FREE_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    log "Свободное место: ${FREE_GB} ГБ"

    if (( FREE_GB < MIN_FREE_GB )); then
        MSG="МАЛО МЕСТА!!! ОСТАЛОСЬ ${FREE_GB} ГБ"
        log "$MSG"
        send_email "Мало места на сервере" "$MSG"
    fi
}


##########################
# МОНИТОРИНГ CPU + RAM
##########################
monitor_memory_cpu() {
    CPU=$(uptime | awk -F"load average:" '{print $2}')
    RAM=$(free -m | awk '/Mem:/ {print $4}')
    log "Загрузка CPU: $CPU"
    log "Свободная RAM: ${RAM} МБ"
}


##########################
# МОНИТОРИНГ ТЕМПЕРАТУРЫ
##########################
monitor_temperature() {
    TEMP=$(sensors 2>/dev/null)
    if [[ -z "$TEMP" ]]; then
        log "Температуру получить нельзя (нет sensors)"
    else
        log "Температура CPU:"
        log "$TEMP"
    fi
}


##########################
# СИСТЕМНЫЕ ОШИБКИ JOURNALCTL
##########################
check_journal_errors() {
    ERRORS=$(journalctl --since "24h ago" | grep -Ei "error|fail|panic")
    if [[ -n "$ERRORS" ]]; then
        log "Ошибки системы:"
        log "$ERRORS"
        send_email "Ошибки в журнале" "$ERRORS"
    else
        log "Ошибок нет"
    fi
}


##########################
# ПРОВЕРКА УПАВШИХ СЕРВИСОВ
##########################
check_services() {
    FAILED=$(systemctl --failed --no-legend)
    if [[ -n "$FAILED" ]]; then
        log "Упавшие сервисы:"
        log "$FAILED"

        while read -r line; do
            svc=$(echo "$line" | awk '{print $1}')
            systemctl restart "$svc"
            log "Перезапущен: $svc"
        done <<< "$FAILED"

        send_email "Проблемы с сервисами" "$FAILED"
    else
        log "Все сервисы работают"
    fi
}


##############################################################
# 🔥 1. МОНИТОРИНГ ПОПЫТОК ВЗЛОМА SSH
##############################################################
monitor_ssh_attacks() {

    # Ищем неудачные попытки входа за 24 часа
    ATTACKERS=$(journalctl -u ssh --since "24 hours ago" | grep "Failed password" | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr)

    if [[ -n "$ATTACKERS" ]]; then
        log "Попытки взлома SSH обнаружены:"
        log "$ATTACKERS"

        # Если fail2ban установлен — добавим IP вручную
        if command -v fail2ban-client >/dev/null; then
            echo "$ATTACKERS" | awk '{print $2}' | while read -r ip; do
                fail2ban-client set sshd banip "$ip"
                log "Fail2Ban: заблокирован IP $ip"
            done
        fi

        send_email "Попытки взлома SSH" "$ATTACKERS"
    else
        log "Взломов SSH нет"
    fi
}


##############################################################
# 🔥 2. Контроль runaway и zombie процессов
##############################################################
monitor_processes() {

    ##############################
    # A) ZOMBIE ПРОЦЕССЫ
    ##############################
    ZOMBIES=$(ps aux | awk '$8=="Z" {print $0}')
    if [[ -n "$ZOMBIES" ]]; then
        log "ZOMBIE процессы:"
        log "$ZOMBIES"
        send_email "Zombie процессы!" "$ZOMBIES"
    else
        log "Zombie-процессов нет"
    fi

    ##############################
    # B) RUNAWAY ПРОЦЕССЫ (CPU > 80%)
    ##############################
    RUNAWAY=$(ps aux --sort=-%cpu | awk '$3>80 {print $0}')

    if [[ -n "$RUNAWAY" ]]; then
        log "Runaway процессы (жрут CPU):"
        log "$RUNAWAY"

        # Мягкое завершение SIGTERM
        echo "$RUNAWAY" | awk '{print $2}' | while read -r pid; do
            kill -15 "$pid"
            sleep 2
            # Если жив → убиваем жестко
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid"
            log "Процесс $pid был завершён"
        done

        send_email "Runaway процессы" "$RUNAWAY"
    else
        log "Runaway-процессов нет"
    fi
}


##############################################################
# ОБНОВЛЕНИЕ СИСТЕМЫ
##############################################################
update_system() {
    log "Начато обновление"
    apt update -y >> "$LOG_FILE" 2>&1
    apt upgrade -y >> "$LOG_FILE" 2>&1
    apt full-upgrade -y >> "$LOG_FILE" 2>&1
    apt autoremove -y >> "$LOG_FILE" 2>&1
    apt autoclean -y >> "$LOG_FILE" 2>&1
    log "Обновление завершено"
}


##############################################################
# ГЛАВНЫЙ БЛОК
##############################################################
rotate_logs
log "===== ЗАПУСК ОБСЛУЖИВАНИЯ ====="
monitor_temperature
monitor_memory_cpu
check_disk
check_journal_errors
check_services
monitor_ssh_attacks
monitor_processes
update_system
log "===== ЗАВЕРШЕНО ====="


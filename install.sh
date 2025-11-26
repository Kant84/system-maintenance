#!/bin/bash

GitHubUser="Kant84"
RepoName="system-maintenance"
Branch="main"
RAW="https://raw.githubusercontent.com/$GitHubUser/$RepoName/$Branch"

# Скачиваем основной скрипт
curl -o /usr/local/bin/system_maintenance.sh $RAW/system_maintenance.sh
chmod +x /usr/local/bin/system_maintenance.sh

# Скачиваем systemd юниты
curl -o /etc/systemd/system/system-maintenance.service $RAW/system-maintenance.service
curl -o /etc/systemd/system/system-maintenance.timer $RAW/system-maintenance.timer

# Обновляем systemd
systemctl daemon-reload

# Включаем таймер
systemctl enable --now system-maintenance.timer

echo "Установка завершена."

#!/bin/bash

set -e

GitHubUser="Kant84"
RepoName="system-maintenance"
Branch="main"
RAW="https://raw.githubusercontent.com/$GitHubUser/$RepoName/$Branch"

# Главный скрипт
curl -s -o /usr/local/bin/system_maintenance.sh $RAW/system_maintenance.sh
chmod +x /usr/local/bin/system_maintenance.sh

# Юниты systemd
curl -s -o /etc/systemd/system/system-maintenance.service $RAW/system-maintenance.service
curl -s -o /etc/systemd/system/system-maintenance.timer $RAW/system-maintenance.timer

# Почтовая подсистема
if ! command -v mail >/dev/null; then
    apt update -y
    apt install -y mailutils
fi

systemctl daemon-reload
systemctl enable --now system-maintenance.timer

echo "Установка завершена."

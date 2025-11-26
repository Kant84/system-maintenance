#!/bin/bash

GitHubUser="Kant84"
RepoName="system-maintenance"
Branch="main"
RAW="https://raw.githubusercontent.com/$GitHubUser/$RepoName/$Branch/system-maintenance"

curl -o /usr/local/bin/system_maintenance.sh $RAW/system_maintenance.sh
chmod +x /usr/local/bin/system_maintenance.sh

curl -o /etc/systemd/system/system-maintenance.service $RAW/system-maintenance.service
curl -o /etc/systemd/system/system-maintenance.timer $RAW/system-maintenance.timer

systemctl daemon-reload
systemctl enable --now system-maintenance.timer

echo "Установка завершена."

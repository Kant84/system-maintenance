#!/bin/bash

RAW="https://raw.githubusercontent.com/Kant84/system-maintenance/main/system-maintenance"

curl -o /usr/local/bin/system_maintenance.sh $RAW/system_maintenance.sh
chmod +x /usr/local/bin/system_maintenance.sh

systemctl daemon-reload

echo "Обновление выполнено."


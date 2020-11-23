#!/bin/zsh

# Don't forget to set GRAFANA_USER, GRAFANA_PASSWORD and CHIPNAME in .screenrc

#/root/enable-rtc.sh
#hwclock -s
#/root/disable-rtc.sh

echo "none" > /sys/class/leds/led0/trigger
touch /run/currenttemp.txt
chmod 644 /run/currenttemp.txt
screen -c /root/.screenrc -S temp-logger -d -m "/root/log-temp.sh"

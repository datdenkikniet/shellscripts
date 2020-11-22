#!/bin/zsh
echo "none" > /sys/class/leds/led0/trigger
/root/enable-rtc.sh
hwclock -s
/root/disable-rtc.sh
touch /run/currenttemp.txt
chmod 644 /run/currenttemp.txt
screen -S temp-logger -d -m /root/log-temp.sh

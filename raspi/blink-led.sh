#!/bin/zsh
current=$(cat /sys/class/leds/led0/brightness)

if [ $current -ge 1 ]; then
    nextval=0    
else
    nextval=1
fi

echo $nextval > /sys/class/leds/led0/brightness


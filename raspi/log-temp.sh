#!/bin/zsh

gettemp(){
    if [ -z $1 ]; then
        echo "No chip type given for gettemp"
        exit 0
    fi
    if [ $1 = "ds3231" ]; then
        templ=$(i2cget -y 1 0x68 0x12)
        tempu=$(i2cget -y 1 0x68 0x11)

        templdec=$(([##10]templ))

        templdec=$(((templdec * 100)/256))
        tempudec=$(([##10]tempu))

        temptotal=$((tempudec*100 + templdec))
        if [ "$tempudec" -gt 127 ] && ((temptotal=temptotal-25600));

        tempudec=$((temptotal/100))
        templdec=$((temptotal%100))

        if [ $templdec -lt 0 ]; then
            templdec=$((templdec*-1))
            if [ $tempudec -eq 0 ]; then
                tempudec="-0"
            fi
        fi
        echo "${tempudec}.${templdec}"
    elif [ $1 = "aht10" ]; then
        if [ -z $aht_init ]; then
            /root/aht10 init
            aht_init=1
        fi
        temp=$(/root/aht10 measq | sed 's/,.*$//')
        echo $temp
    fi
}

getfilesize(){
    file="$1"
    if [ -f $file ]; then
        echo $(du -k "${file}" | cut -f1)
    else
        echo -1
    fi
}

gzipexistingfile(){
    filename=$1
    if [ ! -f $filename ]; then
        echo "${filename} is not an existing file"
    else
        currentvalue=1
        gzipname="${filename}.gz"
        while [ -f "${gzipname}.${currentvalue}" ]; do
            currentvalue=$((currentvalue+1))
        done
        gzipnumname="${gzipname}.${currentvalue}"
        gzip $filename
        mv "${gzipname}" "${gzipnumname}"
        echo "Compressed current ${filename} into ${gzipnumname}"
    fi
}

logtemp() {
    temp=$1
    chip=$2
    wget -q --post-data "temperature,chip=$chip value=$temp" "http://grafana.internal:8086/write?db=temperature" --http-user="$GRAFANA_USER" --http-password="$GRAFANA_PASSWORD"

    # size=$(getfilesize $file)
    # if [ $size -ge 128 ]; then
    #     gzipexistingfile $file
    # fi
    # echo "$(date "+%x %H:%M:%S"), $temp" >> $file

}

currenttemp=/run/currenttemp.txt

if [ -z $CHIPNAME ]; then
    echo "Error! \$CHIPNAME environment variable is not set!"
    exit 1
fi

if [ -z $CHIPTYPE ]; then
    echo "Error! \$CHIPTYPE environment variable is not set!"
    exit 1
fi

if [ -z $GRAFANA_USER ]; then
    echo "Error! \$GRAFANA_USER environment variable is not set!"
    exit 1
fi

if [ -z $GRAFANA_PASSWORD ]; then
    echo "Error! \$GRAFANA_PASSWORD environment variable is not set!"
    exit 1
fi


while sleep 30; do
    tempds=$(gettemp ds3231)
    logtemp $tempds ds3231
    tempah=$(gettemp aht10)
    logtemp $tempah aht10
    echo "$tempds" > $currenttemp
    /root/blink-led.sh
done

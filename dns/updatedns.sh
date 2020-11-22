#!/bin/sh
usage() {
    echomessage "Usage: updatedns.sh [OPTIONS] <username> <password> <interface> <name>"
    echomessage "Options: "
    echomessage "\t-d <domain>\tThe domain to alter (default: $defdomain)."
    echomessage "\t-u <url>\tThe DirectAdmin URL (default: $defurl)."
    echomessage "\t-f <filename>\tThe file to store the old IP in (default: $defipfile)."
    echomessage "\t-o\t\tForcibly update the DNS record."
    echomessage "\t-h\t\tShow this help menu."
}


echomessage() {
    if [ $useeflag -eq 1 ]; then
        echo -e $1
    else
        echo $1
    fi
}

performquery(){
    query="$url/CMD_API_DNS_CONTROL?domain=$domain&json=yes"
    if [ ! -z $1 ]; then
        query="$query&$1"
    fi
    curl -s --user "${username}:${password}" "$query"
}

deldns() {
    if [ ! -z $1 ]; then
        performquery "action=select&arecs0=name%3D$1"
    fi
}

discip() {
    if [ ! -z $1 ]; then
        if [ $useifconfig -eq 1 ]; then
            ip=$(ifconfig $1 inet | tail -n 1 | awk '$1 == "inet" { print $2 }')
        else
            ip=$(ip -o -4 a show dev $1 | awk '{print $4}' | cut -d/ -f1)
        fi
        echo -n $ip
    fi
}

mkdns(){
    if [ ! -z $1 ] && [ ! -z $2 ]; then
        performquery "action=add&type=A&name=$1&value=$2"
    fi
}

loaddns(){
    if [ ! -z $1 ]; then
        output=$(performquery)
        filtered=$(echo $output | grep -e '"name": "$1"')
        echo -n $filtered
    fi
}

defurl=https://web01.ntwrk.eu:2222
defdomain=sursus.nl
defipfile=ip.addr

url=$defurl
domain=$defdomain
ipfile=$defipfile
useeflag=1
useifconfig=1
force=2

while getopts ":d:u:f:heo" option; do
    case $option in
    d)
        domain=$OPTARG
    ;;
    u)
        url=$OPTARG
    ;;
    f)
        ipfile=$OPTARG
    ;;
    e)
        if [ $useeflag -eq 1 ]; then
            useeflag=0
        else
            useeflag=1
        fi
    ;;
    o)
        force=1
    ;;
    h)
        usage
        exit 1
    ;;
    \?)
        echo "Invalid option: $OPTARG"
    ;;
    : )
        echo "Invalid option $OPTARG"
    ;;
    esac
done

shift $((OPTIND - 1))

if [ ! -z $1 ] && [ ! -z $2 ] && [ ! -z $3 ] && [ ! -z $4 ]; then
        username=$1
        password=$2
        interface=$3
        name=$4

        ip=$(discip $interface)
        oldip=$(cat $ipfile)

        if [ $force -eq 1 ] || [ -z $oldip ] || [ ! "$ip" = "$oldip" ]; then
            datestr=$(date)
            echomessage "$datestr"

            if [ ! $force -eq 1 ]; then
                echomessage "IP address has changed from $oldip to $ip."
            else
                echomessage "Forcibly updating DNS record to $ip"
            fi

            if [ -f $ipfile ] || [ $force -eq 1 ]; then
                echomessage "Removing DNS record.\n\tName: $name"
                deldns "${name}"
            else
                touch $ipfile
            fi
            echomessage "Adding DNS record.\n\tName: $name\n\tIP: $ip"
            mkdns "${name}" "${ip}"
            echomessage "Putting new IP $ip in file $ipfile."
            echo -n $ip > $ipfile
        fi
else
    usage
    exit 1
fi

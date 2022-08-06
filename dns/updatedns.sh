#!/bin/sh
usage() {
    echomessage "Usage: updatedns.sh <version> [OPTIONS] <username> <password> <interface> <name>"
    echomessage "<version> can be one of:"
    echomessage "\t4 Update the A record <name> with the IPv4 address of <interface>"
    echomessage "\t6 Update the AAAA record of <name> with the global scope IPv6 address of <interface>"
    echomessage "Options: "
    echomessage "\t-d <domain>\tThe domain to alter (default: $defdomain)."
    echomessage "\t-u <url>\tThe DirectAdmin URL (default: $defurl)."
    echomessage "\t-f <filename>\tThe file to store the old IP addresses in (default: $defipfile)."
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
    if [ ! "$1" = "" ]; then
        query="$query&$1"
    fi
    curl -s --user "${username}:${password}" "$query"
}

deldns() {
    if [ ! "$1" = "" ]; then
        performquery "action=select&arecs0=name%3D$1"
    fi
}

deldns6() {
    if [ ! -z $1 ]; then
        performquery "action=select&aaaarecs0=name%3D$1"
    fi
}

discip() {
    if [ ! "$1" = "" ]; then
        if [ $useifconfig -eq 1 ]; then
            ip=$(ifconfig $1 inet | tail -n 1 | awk '$1 == "inet" { print $2 }')
        else
            ip=$(ip -o -4 a show dev $1 | awk '{print $4}' | cut -d/ -f1)
        fi
        echo -n $ip
    fi
}

discip6() {
   if [ ! "$1" = "" ]; then
        if [ $useifconfig -eq 1 ]; then
            echo "IPv6 support for ifconfig is missing"
            exit 1
        else
            ip=$(ip -o -6 a show scope global dev $1 | awk '{ print $4 }' | cut -d/ -f1)
        fi
        echo -n $ip
   fi
}

mkdns(){
    if [ ! "$1" = "" ] && [ ! "$2" = "" ]; then
        performquery "action=add&type=A&name=$1&value=$2"
    fi
}

mkdns6(){
    if [ ! "$1" = "" ] && [ ! "$2" = "" ]; then
        performquery "action=add&type=AAAA&name=$1&value=$2"
    fi
}

loaddns(){
    if [ ! "$1" = "" ]; then
        output=$(performquery)
        filtered=$(echo $output | grep -e '"name": "$1"')
        echo -n $filtered
    fi
}

if [ "4" = "$1" ]; then
    defipfile=ip.dns
    discip="discip"
    deldns="deldns"
    mkdns="mkdns"
elif [ "6" = "$1" ]; then
    defipfile=ip6.dns
    discip="discip6"
    deldns="deldns6"
    mkdns="mkdns6"
else
    echo "First positional argument must be one of: 4, 6"
    echo ""
    usage
    exit 1
fi

shift

if [ ! "$(echo -e)" = "" ]; then
    useeflag=0
else
    useeflag=1
fi

defurl=https://web01.ntwrk.eu:2222
defdomain=sursus.nl

url=$defurl
domain=$defdomain
ipfile=$defipfile
useifconfig=0
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

        ip=$($discip $interface)
        oldip=$(head -n1 $ipfile 2> /dev/null)

        if [ $force -eq 1 ] || [ -z "$oldip" ] || [ ! "$ip" = "$oldip" ]; then

            datestr=$(date)
            echomessage "$datestr"

            if [ ! $force -eq 1 ]; then
                echomessage "IP address has changed from $oldip to $ip."
            else
                echomessage "Forcibly updating DNS record to $ip"
            fi

            if [ -f $ipfile ] || [ $force -eq 1 ]; then
                echomessage "Removing DNS record.\n\tName: $name"
                $deldns "${name}"
            else
                touch $ipfile
            fi
            echomessage "Adding DNS record.\n\tName: $name\n\tIP: $ip"
            $mkdns "${name}" "${ip}"
            echomessage "Putting new IP $ip in file $ipfile."
            echo "$ip" > "$ipfile"
        fi
else
    usage
    exit 1
fi

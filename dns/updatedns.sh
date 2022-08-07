#!/bin/sh

set -e

usage() {
    echomessage "Usage: updatedns.sh <version> [OPTIONS] <username> <password> <name>"
    echomessage "<version> can be one of:"
    echomessage "\t4 Configure A records with key <name>"
    echomessage "\t6 Configure AAAA records with key <name>"
    echomessage
    echomessage "One of -i or -d must be specified"
    echomessage "Options: "
    echomessage "\t-i <interface>\tUse the address(es) of <interface> to update the remote records"
    echomessage "\t-n <local DNS name>\tUse the address(es) of <local DNS name> to update the remote records"
    echomessage "\t-d <domain>\tThe domain to alter (default: $defdomain)."
    echomessage "\t-u <url>\tThe DirectAdmin URL (default: $defurl)."
    echomessage "\t-f <filename>\tOverride the file in which the old IP addresses are stored."
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
    curl -o /dev/null -s --user "${username}:${password}" "$query"
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
            ip=$(ip -o -4 a show dev $1 | awk '{print $4}' | cut -d/ -f1 | sort)
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
            ip=$(ip -o -6 a show scope global dev $1 | awk '{ print $4 }' | grep -E -v "(^fe)|(^fd)" | cut -d/ -f1 | sort)
        fi
        echo -n $ip
   fi
}

disclocaldnsip() {
    if [ ! "$1" = "" ]; then
        echo "$(dig +short A $1 | sort)"
    fi
}

disclocaldnsglobalip6() {
    if [ ! "$1" = "" ]; then
        echo "$(dig +short AAAA $1 | grep -E -v '(^fd)|(^fe)' | sort)"
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

if [ ! "$(echo -e)" = "" ]; then
    useeflag=0
else
    useeflag=1
fi

if [ "4" = "$1" ]; then
    deldns="deldns"
    mkdns="mkdns"
    v6=0
elif [ "6" = "$1" ]; then
    deldns="deldns6"
    mkdns="mkdns6"
    v6=1
else
    echomessage "Error: First positional argument must be one of: 4, 6"
    echomessage
    usage
    exit 1
fi

shift

defurl=https://web01.ntwrk.eu:2222
defdomain=sursus.nl

url=$defurl
domain=$defdomain
ipfileopt=""
useifconfig=0
force=0
localdnsname=""
ifname=""
verbose=0

while getopts ":n:i:d:u:f:heov" option; do
    case $option in
    d)
        domain=$OPTARG
    ;;
    u)
        url=$OPTARG
    ;;
    f)
        ipfileopt=$OPTARG
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
    i)
        ifname=$OPTARG
    ;;
    n)
        localdnsname=$OPTARG
    ;;
    v)
        verbose=1
    ;;
    \?)
        echo "Invalid option: $OPTARG"
        exit 1
    ;;
    : )
        echo "Invalid option $OPTARG"
        exit 1
    ;;
    esac
done

shift $((OPTIND - 1))

changedname=""

if ([ "$localdnsname" = "" ] && [ "$ifname" = "" ]) || ([ ! "$localdnsname" = "" ] && [ ! "$ifname" = "" ]); then
    echomessage "Error: Exactly one of -n or -i must be specified"
    exit 1
elif [ ! "$localdnsname" = "" ]; then
    if [ $v6 -eq 0 ]; then
        ips=$(disclocaldnsip "$localdnsname")
        ipfile="ip dns ${localdnsname}"
        changedname="local IPv4 DNS name ${localdnsname}"
    else
        ips=$(disclocaldnsglobalip6 "$localdnsname")
        ipfile="ip6 dns ${localdnsname}"
        changedname="local IPv6 DNS name ${localdnsname}"
    fi
else # ! $ifname = ""
    if [ $v6 -eq 0 ]; then
        ips=$(discip "$ifname")
        ipfile="ip if $ifname"
        changedname="IPv4 interface ${ifname}"
    else
        ips=$(discip6 "$ifname")
        ipfile="ip6 if $ifname"
        changedname="IPv6 interface ${ifname}"
    fi
fi

if [ "$ipfileopt" = "" ]; then
    ipfile="$ipfile addrs"
else
    ipfile="$ipfileopt"
fi

if [ ! -z $1 ] && [ ! -z $2 ] && [ ! -z $3 ]; then
        username=$1
        password=$2
        name=$3

        oldips=$(cat "$ipfile" 2> /dev/null)

        if [ $force -eq 1 ] || [ -z "$oldips" ] || [ ! "$ips" = "$oldips" ]; then

            datestr=$(date)
            echomessage "$datestr"

            if [ ! $force -eq 1 ]; then
                echomessage "IP addresses have changed for ${changedname}."
            else
                echomessage "Forcibly updating DNS records."
            fi

            if [ -f "$ipfile" ] || [ $force -eq 1 ]; then
                echomessage "Removing DNS record.\n\tName: $name"
                $deldns "${name}"
            else
                touch "$ipfile"
            fi
            echomessage "Adding DNS records."
            echomessage "\tName: ${name}"

            for addr in $(echo "$ips"); do
                echomessage "\tAddress: ${addr}"
                $mkdns "${name}" "${addr}"
            done

            echomessage "Putting new IP list in file \"$ipfile\"."
            echo "$ips" > "$ipfile"
        elif [ $verbose -eq 1 ]; then
            echomessage "IP addresses have not changed."
        fi
else
    usage
    exit 1
fi

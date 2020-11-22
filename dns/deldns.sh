#!/bin/bash

usage() {
        echo "Usage: deldns.sh [auth] [name]"
}

hasargs=1
if [ -z $1 ] || [ -z $2 ] ; then
        usage
        exit 1
fi

curl "https://web01.ntwrk.eu:2222/CMD_API_DNS_CONTROL?domain=sursus.nl&json=yes&action=select&arecs0=name%3D${2}" --user "${1}"

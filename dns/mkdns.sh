#!/bin/bash

usage() {
	echo "Usage: mkdns.sh [auth] [name] [ip address]"
}

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
	usage
    exit 1
fi
curl "https://web01.ntwrk.eu:2222/CMD_API_DNS_CONTROL?domain=sursus.nl&json=yes&action=add&type=A&name=${2}&value=${3}" --user "${1}"

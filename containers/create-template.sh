#!/bin/bash
#
# SCRIPT: create-template.sh
# AUTHOR: Jona
# DATE: 17-01-2020
# REV: 1.0A
#
# PLATFORM: Linux
#
# PURPOSE: This script is designed to ease the creation of LXC templates. The specified directory is put into a tarfile, which is then compressed with xz(1), ready to be used as an LXC template.
#	   It creates a backup of and restores the /etc/resolv.conf file in the specified directory.
#
# REV LIST:
#
# set -n # uncomment to check syntax
# set -x # uncomment to debug this script

# usage: create-container.sh <directory name> [output file (optional)]

arg1=$1
niceName=$2

usage() {
	echo "Usage: create-container.sh <directory name> [output file (optional)]"
}

if [ ! -f "resolv.conf" ]; then
        echo "No resolv.conf found that can be used to restore! (Create a resolv.conf in this directory)" 
        exit 1
fi


if [ -z $arg1 ]; then
	echo "Please specify a directory!"
	exit 1
fi

if [ ! -d "$arg1" ]; then
	echo "That directory does not exist!"
	exit 1
fi

if [ $# -eq 1 ]; then
        niceName=$(echo "$arg1" | sed 's/\/*$//g')
fi

path=$(realpath -s $1)
tarName=$niceName.tar
xzName=$tarName.xz
resolvBak=.$niceName.resolv.conf.bak

echo "Backing up /etc/resolv.conf"
cp $path/etc/resolv.conf $resolvBak
> $path/etc/resolv.conf

echo "Creating tar archive $tarName..."
tar -C $path -cf $tarName .

echo "Compressing tar archive into $xzName ..."
xz -T 0 -8 -vz $tarName

echo "Restoring /etc/resolv.conf"
cp resolv.conf $path/etc/resolv.conf

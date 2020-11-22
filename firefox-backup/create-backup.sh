#!/bin/bash

# Usage: create-backup.sh <path to profile> <path to output>

usage(){
    echo "Usage: create-backup.sh <path to profile> <path to output file>"
    echo "Output file will be a zstd compressed tar archive"
}


profilepath="$1"
storagefile="$2"

if [ -z $profilepath ]; then
    profilepath="/home/jona/.mozilla/firefox/tbs27p3t.default-1552592972497/"
fi
if [ -z $storagefile ]; then
    storagefile="/home/jona/administratie/jona/firefox-profiles/firefox-profile.tar.zst"
fi
profilepath=$(realpath "$profilepath")
storagefile=$(realpath "$storagefile")

if [ -e $storagefile ] && [ ! -f $storagefile ]; then
    echo "Storage file is not a regular file, will not delete (no action taken)"
elif [ $storagefile == $profilepath ]; then
    echo "Storage file and profile path are the same"
else
    if [ -f $storagefile ]; then
        echo "Removing existing file"
        rm $storagefile
    fi
    echo "Creating tar file"
    tar -I "zstd" -cf "$storagefile" "$profilepath"
fi

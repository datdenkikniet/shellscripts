#!/bin/bash

program_name=$0

ssh_remote="vidar-pastes"
base_url="https://dump.sursus.nl/dump"
base_dir="/var/www/html/dump"
file_suffix=".txt"
use_random_filename=0
output_filename_specified=0
output_filename=""
hash_program="sha256sum"
quiet_mode=1

usage(){
    echo "Usage: upload-txt.sh [options] [filename]"
    echo "This program allows you to upload a file to a remote server over ssh."
    echo "and report back a specific url for accessing it that is also copied"
    echo "into the clipboard."
    echo "[filename] is optional. If it is not specified or - is specified, stdin will be used as input"
    echo "If stdin is used as input or -r is specified, a random filename will be generated. Otherwise, the name of the input file is used."
    echo "Options:"
    echo "   -h         show this help menu."
    echo "   -R         generate a random filename for the remote file. (Cannot be used in conjunction with -n)"
    echo "   -n [name]  use [name] as the name for the remote file. (Cannot be used in conjunction with -r)"
    echo "   -d [dir]   use [dir] as the base directory where the files should be stored. (Default ${base_dir})"
    echo "   -u [url]   use [url] as the base url where the file will be publicly visible. (Default: ${base_url})"
    echo "   -R [rmt]   use [rmt] as the SSH remote. (Default: ${ssh_remote})"
    echo "   -s [sfx]   use [sfx] as the suffix to randomly generated filenames. (Default: ${file_suffix})"
    echo "   -v         verbose mode."
}


while getopts ":hxvrn:d:R:u:" options; do
    case "${options}" in
        r)
            use_random_filename=1
        ;;
        n)
            output_filename="${OPTARG}"
            output_filename_specified=1
        ;;
        d)
           base_dir="${OPTARG}"
        ;;
        R)
            ssh_remote="${OPTARG}"
        ;;
        v)
            quiet_mode=0
        ;;
        u)
            base_url="${OPTARG}"
        ;;
        h)
            usage
            exit 0
        ;;
        :)
            echo "Option -${OPTARG} requires an argument. See $program_name -h for usage."
            exit 1
        ;;
        *)
            echo "Invalid argument -${OPTARG}. See $program_name -h for usage."
            exit 1
        ;;
    esac
done

toshift=$(($OPTIND - 1))
shift $toshift

if [ $use_random_filename -eq 1 ] && [ $output_filename_specified -eq 1 ]; then
    echo "Cannot specify output filename while requiring random name. See $program_name -h for usage."
    exit 1
fi

from_stdin=1

file_name=$output_filename
input_file_name=$1
if [ ! -z $input_file_name ]; then
    if [ ! "${input_file_name}" = "-" ]; then
        from_stdin=0
        input_file="${input_file_name}"
        file_name=$(basename "${input_file_name}")
    fi
fi

if [ $output_filename_specified -eq 1 ]; then
    file_name="${output_filename}"
elif [ $from_stdin -eq 1 ] || [ $use_random_filename -eq 1 ]; then
    file_name=$(($(date +%s%N)/1000000))
    file_name=$(echo "$file_name" | "${hash_program}" | cut -c1-16)
    file_name="${file_name}${file_suffix}"
fi

if [ $quiet_mode -eq 0 ]; then
    echo "Copying input to ${ssh_remote}:${base_dir}/${file_name}"
fi

if [ $from_stdin -eq 0 ]; then
    cat "${input_file}" | ssh "${ssh_remote}" "cat - > ${base_dir}/${file_name}"
else
    ssh "${ssh_remote}" "cat - > ${base_dir}/${file_name}" <&0
fi

retcode=$?

if [ ! $retcode -eq 0 ]; then
    echo "Failed to upload file."
    exit 1
fi

if [ $quiet_mode -eq 0 ]; then
    echo "URL: ${base_url}/${file_name}"
else
   echo "${base_url}/${file_name}"
fi

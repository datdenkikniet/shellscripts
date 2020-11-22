#!/bin/bash
#
# SCRIPT: create-container.sh
# AUTHOR: Jona
# DATE: 17-01-2020
# REV: 1.0A
#
# PLATFORM: Proxmox Virtual Environment (Linux)
#
# REQUIRES: pwgen (if a random password is to be generated)
#
# PURPOSE: This script aids in the creation of containers in PVE. It creates a new container from the specified container template,
# 	   and adds the specified SSH key as an authorized key for the root user. Additionally, it adds the default SSH key of the
#	   user running the script. It then creates a user named CT(cid)@pve, that only has user-level access to the created cont-
#	   ainer. Lastly, it automatically adds the line "lxc.cgroup.devices.allow: c 10:232 rwm" to the container's configuration
#	   file, which enables KVM on the container as well
#
# REV LIST:
#
# set -n # uncomment to check syntax
set -x # uncomment to debug this script

# usage: create-container.sh [OPTIONS] <template file> <ssh key for remote access>

# Get next available CT id
# pvesh get /cluster/nextid/

# Create the container
# pct create [id] [template file] -net0 name=eth0,bridge=[bridge],ip=dhcp --memory [MB] --unprivileged 0 --rootfs [storage]:[size in GB] --ssh-public-keys [ssh key for access] --cores [amt of cores] --password [password]

# Add required lxc option to configuration file so that kvm is passed through to the container, giving much better and faster emulation in gns3 (since it uses QEMU, which uses KVM)
# echo "lxc.cgroup.devices.allow: c 10:232 rwm" >> /etc/pve/nodes/[nodename]/[id].conf

defaultsshkey=~/.ssh/id_rsa.pub
nodename=proxmox
memory=12228
storage=thin-lv
size=8
bridge=vmbr0
cores=2
password="\[random\]"
ip=dhcp
gw=dhcp

verbose=0
debug=0

usage() {
	echo "Usage: create-container.sh [OPTIONS] <template file> <ssh key for remote access>"
	echo "Available options:"
	echo "	-n [name],		The name of this node (default: $nodename)"
	echo "	-m [memory],		Allocate this amount of memory to the container (in MB) (default: $memory)"
	echo "	-t [storage],		Use this storage to store rootfs of the container (default: $storage)"
	echo "	-s [size],		The size of the rootfs of the container (in GB) (default: $size)"
	echo "	-c [core count],	Give the container this many cores (default: $cores)"
	echo "	-b [bridgename],	Use this bridge to create the container's network interface (default: $bridge)"
	echo "	-a [IPv4 addr],		The IPv4 address of the new container. Use dhcp for a DHCP address (default: $ip)"
	echo "	-g [IPv4 addr],		The gateway's IPv4 address for the new container. Required if -a is not dhcp, else unused (default: $gw)"
	echo "	-k [ssh key],		Also add this key to the container's authorized_keys (default: $defaultsshkey, (Using ~/.ssh))"
	echo "	-u [username],		The name of the users that are created. (default: CT[id])"
	echo "	-e [email address],	The email address of the PVE user that is created. (Default: none)"
	echo "	-i [hostname],		Identifier/hostname of the created container (default: CT[id])"
	echo "	-p [password],		The password for the created users (default: $password)"
	echo "	-v,			Enable verbose mode"
	echo "	-h,			Show this help menu and exit"
	echo "	-d			Show debug messages"
}

createContainerAndUser() {
	local cid=$1
	local templateFile=$2
	local netarg=$3
	local memory=$4
	local storage=$5
	local size=$6
	local sshkey=$7
	local defaultsshkey=$8
	local cores=$9
	local password=${10}
	local hostname=${11}
	local username=${12}
	local privileged=${13}

	# create the container
	echo -e "Creating container $hostname..."

	excmd pct create $cid $templatefile -net0 $netarg --memory $memory --unprivileged 0 --rootfs $storage:$size --ssh-public-keys $sshkey  --ssh-public-keys $defaultsshkey --cores $cores --password $password --hostname $hostname
	retCode=$?

	if [ $retCode -eq 0 ]; then
		echo "Adding lxc option"
		echo "lxc.cgroup.devices.allow: c 10:232 rwm" >> /etc/pve/nodes/$nodename/$cid.conf

		# uncomment lines below to automatically start the container
		# echo "Starting container..."
		# pct start $cid

		echo "Creating user"
		userpve=$username@pve
		if [ -z $email ]; then
			excmd pveum user add $userpve --password $password
		else
			excmd pveum user add $userpve --password $password --email $email
		fi
		userAdd=$?

		if [ ! $userAdd -eq 0 ]; then
			echo "Warning! User $userpve existed already! Continuing..."
		fi
		echo "Adding permissions"
		excmd pveum acl modify /vms/$cid --roles PVEVMUser --users $userpve
		exit 0
	else
		echo "Failed to create container."
		exit 1
	fi
}

excmd() {
	if [ $debug -eq 1 ]; then
		echo "$*"
	fi
	if [ $verbose -eq 1 ]; then
		$*
	else
		$* &> /dev/null
	fi
}

temp=$(getopt -o ":n:m:t:s:c:b:a:g:k:p:u:i:e:hvd" -n "create-container.sh" -- "$@")

if [ $? -ne 0 ]; then
	echo "Incorrect options or incorrect arguments provided. See create-container.sh -h for usage."
	exit 1
fi

eval set -- "$temp"
unset temp

# exit 1

while true; do
	case "$1" in
	'-n')
		nodename=$2
		shift 2
		continue
	;;
	'-m')
		memory=$2
        shift 2
		continue
	;;
	'-t')
		storage=$2
		shift 2
		continue
	;;
	'-s')
		size=$2
		shift 2
		continue
	;;
	'-c')
		cores=$2
		shift 2
		continue
	;;
	'-b')
		bridge=$2
		shift 2
		continue
	;;
	'-a')
		ip=$2
		shift 2
		continue
	;;
	'-g')
		gw=$2
		shift 2
		continue
	;;
	'-k')
		defaultsshkey=$2
		shift 2
		continue
	;;
	'-p')
		password=$2
		shift 2
		continue
	;;
	'-u')
		username=$2
		shift 2
		continue
	;;
	'-i')
		hostname=$2
		shift 2
		continue
	;;
	'-v')
		verbose=1
		shift
		continue
	;;
	'-d')
		debug=1
		shift
		continue
	;;
	'-e')
		email=$2
		shift 2
		continue
	;;
	'-h')
		usage
		exit 0
	;;
	'--')
        shift
        break
    ;;
	\?)
		echo "Invalid option: $1"
		exit 1
	;;
	* )
		echo "Invalid option $1"
		exit 1
	;;
	esac
done

if [ "$ip" != "dhcp" ] && [ "$gw" == "dhcp" ]; then
	echo "Must specify both an IP address and a gateway!"
	exit 1
fi

templatefile=$1
sshkey=$2

if [ -z $templatefile ]; then
        echo "Please specify a template file to use! (no arg)"
        exit 1
fi

if [ -z $sshkey ]; then
	echo "Please specify an ssh public key file to use. (no arg)"
	exit 1
fi

if [ ! -f $sshkey ]; then
	echo "Please specify an ssh public key file to use. (not a file)"
	exit 1
fi

if [ ! -f $templatefile ]; then
	echo "Please specify a template file to use. (not a file)"
	exit 1
fi

if [ $password = "\[random\]" ]; then
	pwgenExists=$(command -v pwgen)
	if [ ! $pwgenExists ]; then
		echo "pwgen could not be found!"
		exit 1
	else
		password=$(pwgen 15 1)
	fi
fi

# put down here because it's slow
cid=$(pvesh get /cluster/nextid)

if [ ! $username ]; then
	username=CT$cid
fi

if [ ! $hostname ]; then
	hostname=CT$cid
fi

if [ $verbose -eq 1 ]; then
	echo -e "Options:\n\tUsername: $username\n\tHost name: $hostname\n\tSSH key: $sshkey\n\tTemplate file: $templatefile\n\tSecondary SSH key: $defaultsshkey\n\tNode name: $nodename\n\tMemory: $memory\n\tStorage used: $storage\n\tDisk size: $size\n\tBridge: $bridge\n\tCores: $cores\n\tPassword: $password\n\tIPv4 address: $ip\n\tIPv4 gateway: $gw\n\tEmail address: $email\n"
fi

netarg="name=eth0,bridge=$bridge,ip=dhcp"

if [ ! "$ip" == "dhcp" ]; then
	netarg="name=eth0,bridge=$bridge,ip=$ip,gw=$gw"
fi

createContainerAndUser "$cid" "$templatefile" "$netarg" "$memory" "$storage" "$size" "$sshkey" "$defaultsshkey" "$cores" "$password" "$hostname" "$username" "0"
success=$?

if [ success -eq 0 ]; then
	echo -e "Done.\n\n\n\nDetails:\n\tUsername: $username\n\tPassword: $password\n\tContainer: $hostname"
	exit 0
else
	echo "Task failed succesfully."
	exit 1
fi

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
#	   file, which enables KVM on the container as well. The username will be generated from the email address, and consist of
#	   all of the characters before the '@' sign in the address.
#
# REV LIST:
#
#
# TODO: add an SSH command that adds a pfSense/RADIUS user, so that people can also access the VPN
# set -n # uncomment to check syntax
# set -x # uncomment to debug this script

# usage: create-container.sh [OPTIONS] <template file> <ssh key for remote access> <user email address>

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
	echo "	-n [name]		The name of this node (default: $nodename)"
	echo "	-m [memory]		Allocate this amount of memory to the container (in MB) (default: $memory"
	echo "	-t [storage]		Use this storage to store rootfs of the container (default: $storage)"
	echo "	-s [size]		The size of the rootfs of the container (in GB) (default: $size)"
	echo "	-c [core count],	Give the container this many cores (default: $cores)"
	echo "	-b [bridgename],	Use this bridge to create the container's network interface (default: $bridge)"
	echo "	-a [IPv4 addr],		The IPv4 address of the new container. Use dhcp for a DHCP address (default: $ip)"
	echo "	-g [IPv4 addr],		The gateway's IPv4 address for the new container. Required if -a is not dhcp, else unused (default: $gw)"
	echo "	-k [ssh key],		Also add this key to the container's authorized_keys (default: $defaultsshkey, (Using ~/.ssh))"
	echo "	-p [password]		The password for the created users (default: $password)"
	echo "	-v			Enable verbose mode"
	echo "	-h			Show this help menu and exit"
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
	echo -e "Creating container $containername..."

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

getusername() {
	local ats=$(echo -n $1 | tr -dc '@' | wc -c)
	if [ $ats -eq 1 ]; then
		IFS='@' read -ra USER <<< $1
		echo -n $USER
	fi
}

temp=$(getopt -o ":n:m:t:s:c:b:a:g:k:p:u:i:e:hvd" -n "create-container.sh" -- "$@")

if [ $? -ne 0 ]; then
	echo "Incorrect options or incorrect arguments provided. See create-container-help.sh -h for usage."
	exit 1
fi

eval set -- "$temp"
unset temp

while true; do
	case $1 in
	n)
		nodename=$2
	;;
	m)
		memory=$2
	;;
	t)
		storage=$2
	;;
	s)
		size=$2
	;;
	c)
		cores=$2
	;;
	b)
		bridge=$2
	;;
	a)
		ip=$2
	;;
	g)
		gw=$2
	;;
	k)
		defaultsshkey=$2
	;;
	p)
		password=$2
	;;
	u)
		username=$2
	;;
	i)
		containername=$2
	;;
	v)
		verbose=1
	;;
	d)
		debug=1
	;;
	e)
		email=$OPTARG
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

if [ "$ip" != "dhcp" ] && [ "$gw" == "dhcp" ]; then
	echo "Must specify both an IP address and a gateway!"
	exit 1
fi

shift $((OPTIND - 1))

templatefile=$1
sshkey=$2
email=$3
username=$(getusername "$email")
containername=$username-ct

if [ -z $username ]; then
	echo "Invalid email address."
	exit 1
fi

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

if [ -z $email ]; then
	echo "Please specify an email address to use!"
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

if [ $verbose -eq 1 ]; then
	echo -e "Options:\n\tUsername: $username\n\tContainer name: $containername\n\tSSH key: $sshkey\n\tTemplate file: $templatefile\n\tSecondary SSH key: $defaultsshkey\n\tNode name: $nodename\n\tMemory: $memory\n\tStorage used: $storage\n\tDisk size: $size\n\tBridge: $bridge\n\tCores: $cores\n\tPassword: $password\n\tIPv4 address: $ip\n\tIPv4 gateway: $gw\n\tEmail address: $email\n"
fi

# create the container
echo -e -n "Creating container $containername[ ]\033[2D"

netarg="name=eth0,bridge=$bridge,ip=dhcp"

if [ ! "$ip" == "dhcp" ]; then
	netarg="name=eth0,bridge=$bridge,ip=$ip,gw=$gw"
fi

excmd pct create $cid $templatefile -net0 $netarg --memory $memory --unprivileged 0 --rootfs $storage:$size --ssh-public-keys $sshkey  --ssh-public-keys $defaultsshkey --cores $cores --password $password --hostname $containername
retCode=$?

echo ""

if [ $retCode -eq 0 ]; then
	echo "Adding lxc option"
	echo "lxc.cgroup.devices.allow: c 10:232 rwm" >> /etc/pve/nodes/$nodename/$cid.conf

	# uncomment lines below to automatically start the container
	# echo "Starting container..."
	# pct start $cid

	echo "Creating user"
	userpve=$username@pve
	excmd pveum user add $userpve --password $password --email $email
	userAdd=$?

	if [ ! $userAdd -eq 0 ]; then
		echo "Warning! User $userpve existed already! Continuing..."
	fi
	echo "Adding permissions"
	excmd pveum acl modify /vms/$cid --roles PVEVMUser --users $userpve
	echo -e "Done.\n\n\n\nDetails:\n\tUsername: $username\n\tPassword: $password\n\tContainer: $containername"
	exit 0
else
	echo "Failed to create container."
	exit 1
fi


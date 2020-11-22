#!/bin/bash

cleanup() {
    echo -e "\nDisconnecting..."
    ssh -S $socket -O exit $connect > /dev/null

    echo "Deleting local tuntap device"
    sudo ip link del $localtun
}

socket=/tmp/ssh_tunnel_vpn_socket.sock
localtunnum=0
localtun=tun$localtunnum
localaddr=192.168.255.2/24
remotetunnum=0
remotetun=tun$remotetunnum
remoteaddr=192.168.255.1/24

if [ ! -z $1 ]; then
    localddr=$1
fi

connect="pxeserver"

if [ ! -S $socket ]; then

    echo "Setting up tuntap device"
    sudo ip tuntap add dev $localtun mode tun user jona

    echo "Adding local address"
    sudo ip addr add $localaddr dev $localtun

    echo "Set local tuntap device up"
    sudo ip link set dev $localtun up

    echo "Connecting..."
    ssh -fCMS $socket $connect -o ExitOnForwardFailure=yes -w $localtunnum:$remotetunnum \
     "ip addr add $remoteaddr dev $remotetun;
     ip link set dev $remotetun up"

    success=$?

    if [ $success -eq 0 ]; then
        echo "Succesfully established connection. (Send SIGINT to shutdown)"
        trap cleanup SIGINT
        sleep infinity
    else
        cleanup
        echo "Creating connection failed."
    fi
else
    echo "VPN already connected."
fi

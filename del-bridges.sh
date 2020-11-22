#!/bin/bash
brs=$(sudo ovs-vsctl list-br)
for i in $brs; do
    sudo ovs-vsctl del-br $i
done

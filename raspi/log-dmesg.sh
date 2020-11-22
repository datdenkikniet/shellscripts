while sleep 1; do
	dmesg | tail -n 10 >> dmesg.log
	ip a >> ip.log
done

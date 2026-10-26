for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo on > $s/power/control; done
echo 1dfa000.crypto > /sys/bus/platform/drivers/qcrypto/bind && echo "qcrypto rebound; nosleep control=on restored"

# functional check after a NORMAL suspend/resume (no reboot): are the open UARTs (gamepad MCU, Bluetooth) working again?
irq() { awk '/qcom_geni_serial/ {s=0; for(i=2;i<=9;i++) s+=$i; printf "%s=%d ", $NF, s}' /proc/interrupts; }
echo "  serial IRQs now:      $(irq)"; sleep 5; echo "  serial IRQs +5 s:     $(irq)"
for d in 888000.serial 998000.serial; do printf "  %s runtime=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; echo
echo "  BT: $(bluetoothctl show 2>/dev/null | grep -m1 Powered | tr -d '\t') hci0: $(cat /sys/class/bluetooth/hci0/address 2>/dev/null) mgmt: $(timeout 5 btmgmt info 2>/dev/null | grep -m1 -oE 'current settings: [a-z ]+' | cut -c1-60)"
EV=$(grep -B1 -A6 -iE 'Name=.*(retroid|gamepad|rp5)' /proc/bus/input/devices | grep -m1 -oE 'event[0-9]+')
echo "  gamepad input: /dev/input/$EV bytes in 3 s: $(timeout 3 cat /dev/input/$EV 2>/dev/null | wc -c) (0 = no events; the MCU may only report changes)"
echo "  dmesg after resume (serial/hci/gamepad errors): $(dmesg | tail -60 | grep -ciE 'geni|serial|hci|qca|gamepad|retroid' ) lines"; dmesg | tail -60 | grep -iE 'geni|serial|hci|qca|gamepad|retroid' | tail -4 | cut -c1-140

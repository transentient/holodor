echo 1dfa000.crypto > /sys/bus/platform/drivers/qcrypto/unbind && echo "qcrypto unbound"
echo "crypto requests left in icc: $(grep -c crypto /sys/kernel/debug/interconnect/interconnect_summary)"

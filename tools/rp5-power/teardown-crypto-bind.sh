echo 1dfa000.crypto > /sys/bus/platform/drivers/qcrypto/bind && echo "qcrypto rebound: $(grep -c crypto /sys/kernel/debug/interconnect/interconnect_summary) icc requests"

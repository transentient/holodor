echo 1dfa000.crypto > /sys/bus/platform/drivers/qcrypto/unbind && echo "qcrypto unbound"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 12
for d in 3200000.rxmacro 3220000.txmacro 3370000.codec 3240000.codec 3210000.soundwire 3230000.soundwire; do printf "  %s=%s" $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; echo
grep -E "^ *(LPASS_HW_MACRO|LPASS_HW_DCODEC|LPASS_CLK_ID_TX_CORE_MCLK|LPASS_CLK_ID_TX_CORE_NPL_MCLK|LPASS_CLK_ID_RX_CORE_MCLK|lpass-tx-mclk|lpass-rx-mclk) " /sys/kernel/debug/clk/clk_summary | awk '{printf "  %s=%s", $1, $2} END {print ""}'

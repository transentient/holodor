# setup-AOPNOMSM.sh (2026-10-18): the AOP floor knobs cleared (the 10-17 test of these ran on the charger with the XO
# held, so it proved nothing) on top of the cleanest config we have: msm absent by DT (swap-dtbs.sh apply with the
# nomsm dtbs), S2 (ADSP stopped, wifi link down), undocked. If the counters move here, the AOP's default floors were it.
for k in prevent_aoss_sleep prevent_cx_collapse prevent_ddr_collapse; do
  echo "aoss $k was $(cat /sys/kernel/debug/qcom_aoss/$k 2>&1)"
  if printf 0 > /sys/kernel/debug/qcom_aoss/$k 2>/tmp/aop-err; then echo "aoss $k <- 0 OK"; else echo "aoss $k <- 0 FAILED: $(cat /tmp/aop-err)"; fi
done
ls /sys/kernel/debug/qcom_aoss/ | tr '\n' ' '; echo
sh /var/tmp/rp5-power/setup-NOMSM2.sh

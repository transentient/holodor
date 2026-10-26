#!/bin/sh
# hpset.sh "Control Name=value" ... : amixer cset each pair on card 0
for kv in "$@"; do amixer -q -c0 cset "name=${kv%%=*}" "${kv#*=}" || echo "FAILED $kv"; done

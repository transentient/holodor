rfkill unblock bluetooth && echo "bluetooth unblocked (saved state stays on)"
systemd-run --on-active=30 --unit=sleepcycle-Q-reboot -q systemctl reboot && echo "reboot scheduled in 30 s to restore audio, BT, controls, crypto"

#!/bin/bash

NOTIFY_TITLE0="NORMAL NOTIFY"
NOTIFY_TITLE1="Stop Partial Discharge Failed!"
NOTIFY_TITLE2="Stop Partial Discharge Success!"

NOTIFY_OPT0="normal"
NOTIFY_OPT1="critical"
NOTIFY_OPT2="normal"

# 0. first notify, notify user i'm running.
notify-send -u ${NOTIFY_OPT0} "${NOTIFY_TITLE0}" "I'm running normal, pls hit to close."

# 1. stop PD service.
systemctl stop pddevice.service

# 2. wait a second.
sleep 3

# 3. check JF App status.
for p in jf_recv jf_alg jf_save
do
    pgrep -f "$p" >/dev/null && notify-send -u ${NOTIFY_OPT1} "${NOTIFY_TITLE1}" "Sorry, Process $p is running!" && exit 1;
done

#notify-send -t 3000 -i "notification-message-IM" -u ${NOTIFY_OPT2} "${NOTIFY_TITLE2}" "You can start GasLeakage app manually."
notify-send -t 3000 -i "go-next" -u ${NOTIFY_OPT2} "${NOTIFY_TITLE2}" "You can start GasLeakage app manually."

exit 0


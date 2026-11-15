#!/bin/bash

NOTIFY_TITLE0="NORMAL NOTIFY"
NOTIFY_TITLE1="Stop Gas Leakage Failed!"
NOTIFY_TITLE2="Stop Gas Leakage Success!"

NOTIFY_OPT0="normal"
NOTIFY_OPT1="critical"
NOTIFY_OPT2="normal"

# 0. first notify, notify user i'm running.
notify-send -u ${NOTIFY_OPT0} "${NOTIFY_TITLE0}" "I'm running normal, pls hit to close."

# 1. stop GL service.
systemctl stop gldevice.service

# 2. wait a second.
sleep 3

# 3. check GL App status.
for p in gl_recv gl_alg gl_save
do
    pgrep -f "$p" >/dev/null && notify-send -u ${NOTIFY_OPT1} "${NOTIFY_TITLE1}" "Sorry, Process $p is running!" && exit 1;
done

#notify-send -t 3000 -i "notification-message-IM" -u ${NOTIFY_OPT2} "${NOTIFY_TITLE2}" "You can start ParticalDischarge app manually."
notify-send -t 3000 -i "go-next" -u ${NOTIFY_OPT2} "${NOTIFY_TITLE2}" "You can start ParticalDischarge app manually."

exit 0


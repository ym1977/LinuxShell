#!/bin/bash

NOTIFY_TITLE0="NORMAL NOTIFY"
NOTIFY_TITLE1="Start Gas Leakage Failed!"
NOTIFY_TITLE2="Start Gas Leakage Success!"

NOTIFY_OPT0="normal"
NOTIFY_OPT1="critical"
NOTIFY_OPT2="normal"

# 0. first notify, notify user i'm running.
notify-send -u ${NOTIFY_OPT0} "${NOTIFY_TITLE0}" "I'm running normal, pls hit to close."

# 1. check gl guard.
pgrep -f gl_guard >/dev/null 
if [ $? -eq 0 ]; then
	notify-send -u ${NOTIFY_OPT1} "${NOTIFY_TITLE1}" "Gas Leakage guard app is ready."

	exit 1;
fi

# 2. start GL guard.
/root/Sinwt/GasLeakage/start.sh &

# 3. wait a second.
sleep 5;

# 4. check gl guard again.
pgrep -f gl_guard >/dev/null 
if [ $? -eq 1 ]; then
#	notify-send -u ${NOTIFY_OPT2} "${NOTIFY_TITLE2}" "Gas Leakage guard app is ready."
#else
	notify-send -u ${NOTIFY_OPT1} "${NOTIFY_TITLE1}" "Gas Leakage guard app is not ready, pls retry."

	exit 2;
fi

# 5. wait a second.
sleep 5;

# 6. check gl alg.
pgrep -f gl_alg >/dev/null 
if [ $? -eq 0 ]; then
	notify-send -u ${NOTIFY_OPT2} "${NOTIFY_TITLE2}" "Gas Leakage alg app is ready, begin to start UI."
else
	notify-send -u ${NOTIFY_OPT1} "${NOTIFY_TITLE1}" "Gas Leakage alg app is not ready, pls retry."

	exit 3;
fi

# 7. wait a second.
sleep 20;

# 8. start GL UI.
/root/Sinwt/GasLeakage/gl_ui.sh &

exit 0;


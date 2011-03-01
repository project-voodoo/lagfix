#!/bin/sh
# be sure / is read+write for Gingerbread
/bin/mount -o remount,rw /

exec >> /voodoo/logs/recovery_wrapper_log.txt 2>&1

if test -f /voodoo/run/cwm_enabled; then
	echo "starting CWM recovery"
	exec /voodoo/scripts/cwm_start.sh
else
	if test -x /system/bin/recovery; then
		# Froyo standard recovery 3e
		echo "starting Froyo recovery"
		exec /system/bin/recovery
	else
		# Eclair standard recovery 2e
		echo "starting Eclair recovery"
		exec /sbin/recovery
	fi
fi

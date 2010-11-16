#!/bin/sh
if test -f /voodoo/cwm/sbin/recovery; then
	exec /voodoo/scripts/cwm_start.sh
fi

exec /system/bin/recovery

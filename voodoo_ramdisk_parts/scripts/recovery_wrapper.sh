#!/bin/sh
if test -f /voodoo/cwm/sbin/recovery; then
	/voodoo/scripts/cwm_start.sh&
else
	/system/bin/recovery&
fi

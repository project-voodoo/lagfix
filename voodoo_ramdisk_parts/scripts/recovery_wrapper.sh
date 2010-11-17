#!/bin/sh
if test -f /voodoo/cwm/sbin/recovery; then
	/voodoo/scripts/cwm_start.sh&
fi

/system/bin/recovery&

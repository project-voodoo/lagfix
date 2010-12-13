#!/bin/sh
echo "mount command: $0 $*" > /voodoo/logs/mount_wrapper_log.txt
if test "$2" = 'auto' || test "$2" = 'rfs'; then
	/bin/mount -t ext4 -o noatime,barrier=0,data=ordered $4 $5 || /bin/mount $*
else
	/bin/mount $*
fi

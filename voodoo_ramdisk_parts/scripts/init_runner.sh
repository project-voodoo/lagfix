#!/bin/sh
# logger for Voodoo init script

PATH=/bin:/sbin:/voodoo/scripts

# create used devices nodes
create_devices.sh

# mount the sdcard
mount -t vfat -o utf8 /dev/block/mmcblk0p1 /voodoo/tmp/sdcard

#/voodoo/scripts/init.sh > /voodoo/logs/init.log 2>&1
/voodoo/scripts/init.sh >> /voodoo/tmp/sdcard/init.log 2>&1

# umount the sdcard before running Samsung's init
umount /voodoo/tmp/sdcard

# finally run Samsung's android init binary
exec /init_samsung

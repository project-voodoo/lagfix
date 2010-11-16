#!/bin/sh
# logger for Voodoo init script

PATH=/bin:/sbin:/voodoo/scripts

# create used devices nodes
create_devices.sh

# mount the sdcard
mount -t vfat -o utf8 /dev/block/mmcblk0p1 /voodoo/tmp/sdcard

mv /voodoo/tmp/sdcard/init.log /voodoo/tmp/sdcard/voodoo-init-failed-boot-log-`date '+%Y-%m-%d_%H-%M-%S'`.txt
/voodoo/scripts/init.sh 2>&1 | tee /voodoo/tmp/sdcard/init.log > /voodoo/logs/init.log

# umount the sdcard before running Samsung's init
umount /voodoo/tmp/sdcard

# finally run Samsung's android init binary
exec /init_samsung

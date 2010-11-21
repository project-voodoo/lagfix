#!/bin/sh
# logger for Voodoo init script

PATH=/bin:/sbin:/voodoo/scripts
sdcard='/voodoo/tmp/sdcard'

# create used devices nodes
create_devices.sh

# mount the sdcard for all Galaxy S || or Fascinate
mount -t vfat -o utf8 /dev/block/mmcblk0p1 $sdcard || \
mount -t vfat -o utf8 /dev/block/mmcblk1p1 $sdcard

mkdir -p /voodoo/tmp/sdcard/Voodoo/logs
mv $sdcard/init.log $sdcard/Voodoo/logs/init-failed-boot-log-`date '+%Y-%m-%d_%H-%M-%S'`.txt
/voodoo/scripts/init.sh 2>&1 | tee $sdcard/init.log > /voodoo/logs/init.log

# umount the sdcard before running Samsung's init
umount $sdcard

# finally run Samsung's android init binary
exec /init_samsung

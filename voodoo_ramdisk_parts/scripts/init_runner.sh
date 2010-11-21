#!/bin/sh
# logger for Voodoo init script

PATH=/bin:/sbin:/voodoo/scripts

. /voodoo/configs/shared

# create used devices nodes
create_devices.sh

# mount the sdcard for all Galaxy S || or Fascinate
mount -t vfat -o utf8 /dev/block/mmcblk0p1 $sdcard || \
mount -t vfat -o utf8 /dev/block/mmcblk1p1 $sdcard

# save the logs of a failed boot
mv $log_dir $sdcard/Voodoo/logs/boot-`date '+%Y-%m-%d_%H-%M-%S'`-failed

mkdir -p $log_dir
/voodoo/scripts/init.sh 2>&1 | tee $log_dir/init_log.txt > /voodoo/logs/init_log.txt

# umount the sdcard before running Samsung's init
umount $sdcard

# finally run Samsung's android init binary
exec /init_samsung

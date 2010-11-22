#!/bin/sh
# logger for Voodoo init script

PATH=/bin:/sbin:/voodoo/scripts
. /voodoo/configs/shared

# create used devices nodes
create_devices.sh

# proc and sys are  used
mount -t proc proc /proc
mount -t sysfs sys /sys

# mount the sdcard for Galaxy S and Fascinate
# detect Fascinate
if test "`cat /sys/block/mmcblk0/size`" = 3907584; then
	# we are on fascinate,
	mount -t vfat -o utf8 /dev/block/mmcblk1p1 $sdcard
else
	# every other Galaxy S
	mount -t vfat -o utf8 /dev/block/mmcblk0p1 $sdcard
fi

# save the logs written during unfinished boots
mv $log_dir $sdcard/Voodoo/logs/boot-`date '+%Y-%m-%d_%H-%M-%S'`-error

mkdir -p $log_dir
/voodoo/scripts/init.sh 2>&1 | tee $log_dir/init_log.txt > /voodoo/logs/init_log.txt

# umount the sdcard before running Samsung's init
umount $sdcard

# finally run Samsung's android init binary
exec /init_samsung

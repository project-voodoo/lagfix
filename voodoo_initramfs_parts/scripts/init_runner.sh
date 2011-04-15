#!/bin/sh
# logger / runner for Voodoo init script
exec > /voodoo/logs/init_runner_log.txt 2>&1

echo "Hello Voodoo:\n"

PATH=/bin:/sbin:/voodoo/scripts
# load configs
. /voodoo/configs/partitions
. /voodoo/configs/shared


# stupid anti-boot-glitch with froyo kernels
# remove a file present in the initramfs for the only purpose to prevent
# the infamous screen glitch appearing at some zImage or initramfs size
# this is only a harmless workaround
# how to create such a file: dd if=/dev/zero of=anti_glitch bs=1024 count=1024
# in your initramfs
rm -f anti_boot_glitch


# create used devices nodes
create_devices.sh


# proc and sys are  used
mount -t proc proc /proc
mount -t sysfs sys /sys


# insmod required filesystem modules
insmod /lib/modules/fsr.ko
insmod /lib/modules/fsr_stl.ko
insmod /lib/modules/rfs_glue.ko
insmod /lib/modules/rfs_fat.ko


# insmod Ext4 modules for injected initramfs without Ext4 driver builtin
test -f /lib/modules/crc16.ko && insmod /lib/modules/crc16.ko
test -f /lib/modules/jbd2.ko && insmod /lib/modules/jbd2.ko
test -f /lib/modules/ext4.ko && insmod /lib/modules/ext4.ko


# setup sdcard for Voodoo lagfix
test -e sdcard && mv -f sdcard sdcard_backup
mkdir /sdcard


# reliability optimisation:
# Android tend to never umount the sdcard properly and there are a lot of errors
# dirty tentative to repair broken vfat on sdcard
repair_sdcard_vfat()
{
	if mount -t rfs -o ro $system_partition /system 2>/dev/null || mount -t ext4 -o ro $system_partition /system; then
		/system/bin/fsck_msdos -y $sdcard_dev
		# sometimes it takes 2 attemps
		/system/bin/fsck_msdos -y $sdcard_dev
		umount /system
	fi
}


# mount the sdcard for Galaxy S and Fascinate/Mesmerize/Showcase
# detect Fascinate/Mesmerize/Showcase
# jt1134 idea: limit to 5s the sdcard mount wait
sdcard_is_mounted=0
wait=0
mount_attemps=5
while test $sdcard_is_mounted = 0 && test $mount_attemps -gt 0; do
	sleep $wait

	if test "`cat /sys/block/mmcblk0/size`" = 3907584 || test "`cat /sys/block/mmcblk0/size`" = 3825664; then
		sdcard_dev=/dev/block/mmcblk1p1	# we are on fascinate/mesmerize/showcase/vzw-galaxytab
	else
		sdcard_dev=/dev/block/mmcblk0p1	# every other Galaxy S
	fi

	repair_sdcard_vfat
	mount -t vfat -o utf8,errors=continue $sdcard_dev /sdcard && sdcard_is_mounted=1 || wait=1

	mount_attemps=$(( $mount_attemps - 1 ))
done

# save the real status of the sdcard mount: if it's not, we won't proceed to conversions later
! test $sdcard_is_mounted = 1 && > /voodoo/run/no_sdcard

# save the logs written during unfinished boots
mv $log_dir /sdcard/Voodoo/logs/`date '+%Y-%m-%d_%H-%M-%S'`-error 2>/dev/null

mkdir -p $log_dir
echo "\nRunning Voodoo init:"
/voodoo/scripts/init.sh 2>&1 | tee $log_dir/init_log.txt > /voodoo/logs/init_log.txt


# umount the sdcard before running Samsung's init and restore its state
umount /sdcard && rm -r sdcard
test -e sdcard_backup && mv -f  sdcard


# finally run Samsung's android init binary
echo "\nRunning Samsung's Android init:"
exec /init_samsung

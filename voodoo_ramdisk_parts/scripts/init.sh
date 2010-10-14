#!/bin/sh
###############################################################################
#                                                                             #
#    Voodoo lagfix for Samung mobile                                          #
#                                                                             #
#    http://project-voodoo.org/                                               #
#                                                                             #
#    Devices supported and tested :                                           #
#      o Galaxy S international - GT-I9000 8GB and 16GB                       #
#      o Bell Vibrant GT-I9000B                                               #
#      o T-Mobile Vibrant 16GB                                                #
#      o AT&T Captivate                                                       #
#                                                                             #
#    Copyright Francois Simond 2010 (supercurio @ xda-developers)             #
#       credits to gilsken for ideas and support                              #
#                                                                             #
#    Released under the GPLv3                                                 #
#                                                                             #
#    This program is free software: you can redistribute it and/or modify     #
#    it under the terms of the GNU General Public License as published by     #
#    the Free Software Foundation, either version 3 of the License, or        #
#    (at your option) any later version.                                      #
#                                                                             #
#    This program is distributed in the hope that it will be useful,          #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
#    GNU General Public License for more details.                             #
#                                                                             #
#    You should have received a copy of the GNU General Public License        #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.    #
#                                                                             #
###############################################################################

set -x
PATH=/bin:/sbin:/usr/bin/:/usr/sbin:/system/bin:/system/sbin

data_archive='/sdcard/voodoo_user-data.cpio'

alias mount_data_ext4="mount -t ext4 -o noatime,nodiratime /dev/block/mmcblk0p4 /data"
alias mount_data_rfs="mount -t rfs -o nosuid,nodev,check=no /dev/block/mmcblk0p2 /data"
alias mount_sdcard="mount -t vfat -o utf8 /dev/block/mmcblk0p1 /sdcard"
alias mount_cache="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl11 /cache"
alias mount_dbdata="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl10 /dbdata"
alias check_dbdata="fsck_msdos -y /dev/block/stl10"

alias make_backup="find /data /dbdata | cpio -H newc -o > $data_archive"
alias blkrrpart="hdparm -z /dev/block/mmcblk0"

debug_mode=0

load_stage() {
	# don't reload a stage already in memory
	if ! test -f /tmp/stage$1_loaded; then
		case $1 in
			2)
				# this stage is in ramdisk. no security check
				log "load stage2"
				xzcat /voodoo/stage2.cpio.xz | cpio -div
			;;
			*)
				# give the option to load without signature
				# from the ramdisk itself
				# useful for testing and when size don't matter
				if test -f /voodoo/stage$1.cpio.xz; then
					log "load stage $1 from ramdisk"
					xzcat /voodoo/stage$1.cpio.xz | cpio -div
				fi

				stagefile="/sdcard/Voodoo/resources/stage$1.cpio.xz"

				# load the designated stage after verifying it's
				# signature to prevent security exploit from sdcard
				signature=`sha1sum $stagefile | cut -d' ' -f 1`
				for x in `cat /voodoo/signatures/$1`; do
					if test "$x" = "$signature"  ; then
						log "load stage $1 from SD"
						xzcat $stagefile | cpio -div
						break
					fi
				done
				log "stage $1 not loaded, signature mismatch"

			;;
		esac
		> /tmp/stage$1_loaded
	fi
}

detect_supported_model() {
	# read the actual MBR
	dd if=/dev/block/mmcblk0 of=/tmp/original.mbr bs=512 count=1

	for x in /voodoo/mbrs/samsung/* /voodoo/mbrs/voodoo/* ; do
		if cmp $x /tmp/original.mbr; then
			model=`echo $x | /bin/cut -d \/ -f4`
			break
		fi
	done

	log "model detected: $model"
}

set_partitions() {
	case $1 in
		samsung)
			if test "$current_partition_model" != "samsung"; then
				cat /voodoo/mbrs/samsung/$model > /dev/block/mmcblk0
				log "set Samsung partitions"
				blkrrpart 
			fi
		;;
		voodoo)
			if test "$current_partition_model" != "voodoo"; then
				cat /voodoo/mbrs/voodoo/$model > /dev/block/mmcblk0
				log "set voodoo partitions"
				blkrrpart
			fi
		;;
	esac

	current_partition_model=$1
}

fast_wipe_ext4_and_build_rfs() {
	# re-write an almost empty rfs partition
	# fast wipe :
	# a few first MB
	xzcat /voodoo/rfs_partition/start.img.xz > /dev/block/mmcblk0p2
	# 10MB around the 220MB limit
	xzcat /voodoo/rfs_partition/+215M.img.xz \
		| dd bs=1024 seek=$((215*1024)) of=/dev/block/mmcblk0p2
}

check_free() {
	# FIXME: add the check if we have enough space based on the
	# space lost with Ext4 conversion with offset
	
	# read free space on internal SD
	target_free=`df /sdcard | cut -d' ' -f 6 | cut -d K -f 1`

	# read space used by data we need to save
	space_needed=$((`df /data | cut -d' ' -f 4 | cut -d K -f 1` \
			+ `df /dbdata | cut -d' ' -f 4 | cut -d K -f 1`))

	log "free space : $target_free"
	log "space needed : $space_needed"

	# more than 100MB on /data, talk to the user
	test $space_needed -gt 102400 && say "wait"

	# FIXME: get a % of security
	test $target_free -ge $space_needed
}

ext4_check() {
	log "ext4 partition detection"
	set_partitions voodoo
	if test "`echo $(blkid /dev/block/mmcblk0p4) | cut -d' ' -f3 \
		| cut -d'"' -f2`" = "ext4"; then
		log "ext4 partition detected"
		set_partitions samsung
		mount_data_rfs
		if test -f /data/protection_file; then
			log "protection file present"
			umount /data
			return 0
		fi

		mount_sdcard
		say "data-wiped"
		umount /sdcard
		
		log "ext4 present but protection file absent"
		return 1
	fi
	log "no ext4 partition detected"
	return 1
}

restore_backup() {
	# clean any previous false dbdata partition
	rm -r /dbdata/*
	# extract from the backup,
	# with dirty workaround to fix battery level inaccuracy
	# then remove the backup file if everything went smooth
	cat $data_archive | cpio -div && rm $data_archive
	rm /data/system/batterystats.bin
}

log() {
	log="Voodoo: $1"
	echo -e "\n  ###  $log\n" >> /init.log
	echo `date '+%Y-%m-%d %H:%M:%S'` $log >> /voodoo.log
}

say() {
	# sound system lazy loader
	load_soundsystem
	# play !
	madplay -A -4 -o wave:- "/voodoo/voices/$1.mp3" | \
		 aplay -Dpcm.AndroidPlayback_Speaker --buffer-size=4096
}

load_soundsystem() {
	# load alsa libs & players
	load_stage 3-sound

	# cache the voices from the SD to the ram
	# with a size limit to prevent filling memory security expoit
	if ! test -d /voodoo/voices; then
		if test `du -s /sdcard/Voodoo/resources/voices/ | cut -d \/ -f1` -le 1024; then
			# copy the voices, using cpio as a "cp" replacement (shrink)
			cd /sdcard/Voodoo/resources
			find voices/ | cpio -p /voodoo
			cd /
			log "voices loaded"
		else
			log "error, voice diretory strangely big"
		fi
	fi
}

letsgo() {
	# paranoid security: prevent any data leak
	test -f $data_archive && rm -v $data_archive
	# dump logs to the sdcard
	mount_sdcard
	# create the Voodoo dir in sdcard if not here already
	test -f /sdcard/Voodoo && rm /sdcard/Voodoo
	mkdir /sdcard/Voodoo

	log "running init !"

	if test $debug_mode = 1; then
		# copy some logs in it to help beta debugging
		mkdir /sdcard/Voodoo/logs
		
		cat /voodoo.log >> /sdcard/Voodoo/logs/voodoo.txt
		echo >> /sdcard/Voodoo/logs/voodoo.txt
		
		cat /init.log > /sdcard/Voodoo/logs/init-"`date '+%Y-%m-%d_%H-%M-%S'`".txt
	else
		# we are not in debug mode, let's wipe stuff to free some MB of memory !
		rm -r /voodoo
		# clean now broken symlinks
		rm /bin /usr
		# clean debugs logs too
		rm -r /sdcard/Voodoo/logs
	fi

	umount /sdcard
	# set the etc to Android standards
	rm /etc
	ln -s /system/etc /etc
	
	
	umount /system
	
	# run Samsung's init and disappear
	exec /sbin/init
}

# STAGE 1

# proc and sys are  used 
mount -t proc proc /proc
mount -t sysfs sys /sys

# create used devices nodes
# standard
mknod /dev/null c 1 3
mknod /dev/zero c 1 5

# internal & external SD
mknod /dev/block/mmcblk0 b 179 0
mknod /dev/block/mmcblk0p1 b 179 1
mknod /dev/block/mmcblk0p2 b 179 2
mknod /dev/block/mmcblk0p3 b 179 3
mknod /dev/block/mmcblk0p4 b 179 4
mknod /dev/block/mmcblk1 b 179 8
mknod /dev/block/stl1 b 138 1
mknod /dev/block/stl2 b 138 2
mknod /dev/block/stl3 b 138 3
mknod /dev/block/stl4 b 138 4
mknod /dev/block/stl5 b 138 5
mknod /dev/block/stl6 b 138 6
mknod /dev/block/stl7 b 138 7
mknod /dev/block/stl8 b 138 8
mknod /dev/block/stl9 b 138 9
mknod /dev/block/stl10 b 138 10
mknod /dev/block/stl11 b 138 11
mknod /dev/block/stl12 b 138 12

# soundcard
mknod /dev/snd/controlC0 c 116 0
mknod /dev/snd/controlC1 c 116 32
mknod /dev/snd/pcmC0D0c c 116 24
mknod /dev/snd/pcmC0D0p c 116 16
mknod /dev/snd/pcmC1D0c c 116 56
mknod /dev/snd/pcmC1D0p c 116 48
mknod /dev/snd/timer c 116 33


# insmod required modules
insmod /lib/modules/fsr.ko
insmod /lib/modules/fsr_stl.ko
insmod /lib/modules/rfs_glue.ko
insmod /lib/modules/rfs_fat.ko
insmod /lib/modules/j4fs.ko
insmod /lib/modules/dpram.ko


# new in beta5, using /system
mount -t rfs -o ro,check=no /dev/block/stl9 /system 
# copy the sound configuration
cat /system/etc/asound.conf > /etc/asound.conf

# hardware-detection
detect_supported_model
if test "$model" = ""  ; then
	# model not supported
	log "this model is not supported"
	mount_data_rfs
	letsgo
fi


# unpack myself : STAGE 2
load_stage 2

# detect the MASTER_CLEAR intent command
# this append when you choose to wipe everything from the phone settings,
# or when you type *2767*3855# (Factory Reset, datas + SDs wipe)
mount_cache
if test -f /cache/recovery/command; then

	if test `cat /cache/recovery/command | cut -d '-' -f 3` = 'wipe_data'; then
		log "MASTER_CLEAR mode"
		say "factory-reset"
		# if we are in this mode, we still have to wipe ext4 partition start
		set_partitions samsung
		# recovery will find Samsung's partition, will wipe them and be happy !
		fast_wipe_ext4_and_build_rfs
		umount /cache
		letsgo
	fi
fi
umount /cache



# first : read instruction from sdcard and do it !
mount_sdcard

# debug mode detection
if test "`find /sdcard/Voodoo/ -iname 'enable*debug*'`" != "" ; then
	echo "service adbd_voodoo_debug /sbin/adbd" >> /init.rc
	echo "	root" >> /init.rc
	echo "	enabled" >> /init.rc
	debug_mode=1
fi


if test "`find /sdcard/Voodoo/ -iname 'disable*lagfix*'`" != "" ; then
	umount /sdcard
	
	if ext4_check; then

		log "lag fix disabled and ext4 detected"
		# ext4 partition detected, let's convert it back to rfs :'(
		# mount resources
		set_partitions voodoo
		mount_data_ext4
		mount_dbdata
		mount_sdcard
		say "to-rfs"
		
		log "run backup of ext4 /data"
		
		# check if there is enough free space for migration or cancel
		# and boot
		if ! check_free; then
			log "not enough space to migrate from ext4 to rfs"
			say "cancel-no-space"
			mount_data_ext4
			letsgo
		fi
		
		say "step1"&
		make_backup
		
		# umount mmcblk0 resources
		umount /dbdata
		umount /sdcard
		umount /data

		# restore Samsung's partition layout on the internal SD
		set_partitions samsung
		
		fast_wipe_ext4_and_build_rfs

		# remove the gigantic protection_file
		log "mount rfs /data"
		mount_data_rfs
		rm /data/protection_file

		# restore the data archived
		mount_sdcard
		log "restore backup on rfs /data"
		say "step2"
		restore_backup
		umount /sdcard

		say "success"

	else

		# in this case, we did not detect any valid ext4 partition
		# hopefully this is because mmcblk0p2 contains a valid rfs /data
		log "lag fix disabled, rfs present"
		set_partitions samsung
		log "mount /data as rfs"
		mount_data_rfs

	fi

	# now we know that /data is in RFS anyway. let's fire init !
	letsgo

fi
umount /sdcard

# Voodoo lagfix is enabled
# detect if the data partition is in ext4 format
log "lag fix enabled"
if ! ext4_check ; then

	log "no protected ext4 partition detected"

	# no protected ext4 partition detected, we will convert to ext4
	# for that we first need to restore Samsung's partition table
	set_partitions samsung
	
	# mount resources we need
	log "mount resources to backup"
	mount_data_rfs
	mount_dbdata
	mount_sdcard
	say "to-ext4"

	# check if there is enough free space for migration or cancel
	# and boot
	if ! check_free; then
		log "not enough space to migrate from rfs to ext4"
		say "cancel-no-space"
		set_partitions samsung
		mount_data_rfs
		letsgo
	fi

	# run the backup operation
	log "run the backup operation"
	if ! test -f /data/protection_file; then
		say "step1"&
		make_backup
	else
		# something's wrong :(
		log "error: protection file present in rfs but no ext4 data"
	fi
	
	# umount mmcblk0 resources
	umount /sdcard
	umount /data
	
	# write the fake protection file on mmcblk0p2, just in case
	log "fast write the giant protection file on mmcblk0p2" 
	fast_wipe_ext4_and_build_rfs
	
	# set our partitions back 
	set_partitions voodoo

	# build the ext4 filesystem
	log "build the ext4 filesystem"
	
	# (empty) /etc/mtab is required for this mkfs.ext4
	cat /etc/mke2fs.conf
	mkfs.ext4 -F -O sparse_super /dev/block/mmcblk0p4
	# force check the filesystem after 100 mounts or 100 days
	tune2fs -c 100 -i 100d -m 0 /dev/block/mmcblk0p4
		
	mount_data_ext4
	mount_sdcard

	# restore the data archived
	say "step2"
	restore_backup

	# clean all these mounts
	log "umount what will be re-mounted by Samsung's Android init"
	umount /dbdata
	umount /sdcard
	
	say "success"&

else

	# seems that we have a ext4 partition ;) just mount it
	set_partitions voodoo
	log "protected ext4 detected, mounting ext4 /data !"
	e2fsck -p /dev/block/mmcblk0p4
	mount_data_ext4

fi

# run Samsung's Android init
letsgo

#!/bin/sh
###############################################################################
#                                                                             #
#    Voodoo lag fix for Samung mobile                                         #
#    Devices supported and tested :                                           #
#      o Galaxy S international - GT-I9000 8GB                                #
#      o Galaxy S international - GT-I9000 16GB                               #
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
#set -x
PATH=/bin:/sbin:/usr/bin/:/usr/sbin

data_archive='/sdcard/voodoo_user-data.tar'
protect_image='/res/mmcblk0p2_protectionmode.img.bz2'

alias mount_data_ext4="mount -t ext4 -o noatime,nodiratime /dev/block/mmcblk0p4 /data"
alias mount_data_rfs="mount -t rfs -o nosuid,nodev,check=no /dev/block/mmcblk0p2 /data"
alias mount_sdcard="mount -t vfat -o utf8 /dev/block/mmcblk0p1 /sdcard"
alias mount_cache="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl11 /cache"
alias mount_dbdata="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl10 /dbdata"

alias make_backup="tar cf $data_archive /data /dbdata "
alias blkrrpart="sfdisk -R /dev/block/mmcblk0"


model=""
current_partition_model=""
detect_supported_model() {
	# read the actual MBR
	dd if=/dev/block/mmcblk0 of=/tmp/original.mbr bs=512 count=1

	cd /res/mbr_stock
	for x in * ; do
		if cmp $x /tmp/original.mbr; then
			model=$x
			continue
		fi
	done

	log "model detected: $model"
	cd /
}

set_partitions() {
	case $1 in
		samsung)
			if test "$current_partition_model" != "samsung"; then
				cat /res/mbr_stock/$model > /dev/block/mmcblk0
				log "set Samsung partitions"
				blkrrpart 
			fi
		;;
		custom)
			if test "$current_partition_model" != "custom"; then
				cat /res/mbr_fixed/$model > /dev/block/mmcblk0
				log "set custom partitions"
				blkrrpart
			fi
		;;
	esac

	current_partition_model=$1
}

fast_wipe_ext4_and_build_rfs() {
	# re-write an almost empty rfs partition
	# fast wipe :
	# 5 first MB
	bunzip2 -c $protect_image \
		| dd ibs=1024 count=5k of=/dev/block/mmcblk0p2
	# 10MB around the 220MB limit
	bunzip2 -c $protect_image \
		| dd ibs=1024 obs=1024 skip=215k seek=215k count=10k \
		of=/dev/block/mmcblk0p2
}

make_backup_conditional() {
	# create a backup only if there is not already one that looks valid here
	if ! tar tf $data_archive  \
			data/data/com.android.settings \
			dbdata/databases/com.android.providers.settings; then
		make_backup
	fi
}

check_free() {
	# read free space on internal SD
	target_free=`df /sdcard | awk '/\/sdcard$/ {print $2}'`
	# read space used by data we need to save
	space_needed=$((`df /data | awk '/ \/data$/ {print $3}'` \
			+ `df /dbdata | awk '/ \/dbdata$/ {print $3}'`))
	log "free space : $target_free"
	log "space needed : $space_needed"
	# more than 100MB on /data, talk to the user
	if test $space_needed -gt 102400; then
		say "wait"
	fi
	return `test "$target_free" -ge "$space_needed"`
}

ext4_check() {
	log "ext4 partition detection"
	set_partitions custom
	if dumpe2fs -h /dev/block/mmcblk0p4; then
		log "ext4 partition detected"
		set_partitions samsung
		mount_data_rfs
		if test -f /data/protection_file; then
			log "protection file present"
			umount /data
			return 0
		fi
		say "data-wiped"
		log "ext4 present but protection file absent"
		return 1
	fi
	log "no ext4 partition detected"
	return 1
}

restore_backup() {
	# clean any previous false dbdata partition
	rm -rf /dbdata/*
	# extract from the tar backup,
	# with dirty workaround to fix battery level inaccuracy
	# then remove the backup tarball if everything went smooth
	tar xf $data_archive --exclude=/data/system/batterystats.bin \
		&& rm $data_archive
}

log() {
	log="Voodoo lagfix: $1"
	logs="$logs  /  "`date '+%Y-%m-%d %H:%M:%S '`$log
	echo -e "\n  ###  $log\n" >> /init.log
	echo $log >> /voodoo.log
}

say() {
	madplay -A -4 -o wave:- "/res/voices/$1.mp3" | \
		 aplay -Dpcm.AndroidPlayback_Speaker --buffer-size=4096
}

letsgo() {
	log "running init !"
	# dump logs to the sdcard
	mount_sdcard
	echo -e "$logs\n" >> /sdcard/Voodoo/voodoo_log.txt
	cp /init.log /sdcard/Voodoo
	umount /sdcard
	
	# workaround for T-Mobile Vibrant crappy workarounds
	if test "$model" = "16GB-tmo-vibrant"; then
		cat /tmp/original.mbr > /dev/block/mmcblk0
	fi

	exec /sbin/init
}

# proc and sys are  used 
mount -t proc proc /proc
mount -t sys sys /sys


# first thing: set the CPU to a fixed frequency for finky ones
default_governor=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# insmod required modules
insmod /lib/modules/fsr.ko
insmod /lib/modules/fsr_stl.ko
insmod /lib/modules/rfs_glue.ko
insmod /lib/modules/rfs_fat.ko
insmod /lib/modules/j4fs.ko
insmod /lib/modules/dpram.ko


# hardware-detection
detect_supported_model
if test "$model" = ""  ; then
	# model not supported
	log "this model is not supported"
	mount_data_rfs
	letsgo
fi


# detect the MASTER_CLEAR intent command
# this append when you choose to wipe everything from the phone settings,
# or when you type *2767*3855# (Factory Reset, datas + SDs wipe)
mount_cache
if test -f /cache/recovery/command; then

	if fgrep -- '--wipe_data' /cache/recovery/command; then
		log "MASTER_CLEAR mode"
		say "factory-reset"
		# if we are in this mode, we still have to wipe ext4 partition start
		set_partitions samsung
		# recovery will find Samsung's partition, will wipe them and be happy !
		fast_wipe_ext4_and_build_rfs
		umount /cache
		# restore the default CPU governor
		echo $default_governor > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
		letsgo
	fi
fi
umount /cache



# first : read instruction from sdcard and do it !
mount_sdcard
if test `find /sdcard/Voodoo/ -iname 'disable*lagfix*' | wc -l` -ge 1 ; then
	umount /sdcard
	
	if ext4_check; then

		log "lag fix disabled and ext4 detected"
		say "to-rfs"
		# ext4 partition detected, let's convert it back to rfs :'(
		# mount ressources
		set_partitions custom
		mount_data_ext4
		mount_dbdata
		mount_sdcard
		
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
		make_backup_conditional
		
		# umount mmcblk0 ressources
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
	say "to-ext4"

	# no protected ext4 partition detected, we will convert to ext4
	# for that we first need to restore Samsung's partition table
	set_partitions samsung
	
	# mount ressources we need
	log "mount ressources to backup"
	mount_data_rfs
	mount_dbdata
	mount_sdcard

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
		make_backup_conditional
	else
		# something's wrong :(
		log "error: protection file present in rfs but no ext4 data"
		log "let's hope that a backup is still present"
	fi
	
	# umount mmcblk0 ressources
	umount /sdcard
	umount /data
	
	# write the fake protection file on mmcblk0p2, just in case
	log "write the fake protection file on mmcblk0p2, just in case" 
	bunzip2 -c $protect_image \
		| dd ibs=1024 count=5k of=/dev/block/mmcblk0p2
	
	# set our partitions back 
	set_partitions custom

	# build the ext4 filesystem
	log "build the ext4 filesystem"
	
	# (empty) /etc/mtab is required for this mkfs.ext4
	mkfs.ext4 -F -E lazy_itable_init=1 -O sparse_super,uninit_bg \
		/dev/block/mmcblk0p4
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
	set_partitions custom
	log "protected ext4 detected, mounting ext4 /data !"
	e2fsck -p /dev/block/mmcblk0p4
	mount_data_ext4

fi

# run Samsung's Android init
letsgo

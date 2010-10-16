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
set -x
PATH=/bin:/sbin:/usr/bin/:/usr/sbin

data_archive='/sdcard/voodoo_user-data.tar'
protect_image='/res/mmcblk0p2_protectionmode.img.bz2'

alias mount_data_ext4="mount -t ext4 -o noatime,nodiratime /dev/block/mmcblk0p4 /data"
alias mount_data_rfs="mount -t rfs -o nosuid,nodev,check=no /dev/block/mmcblk0p2 /data"
alias mount_sdcard="mount -t vfat -o utf8 /dev/block/mmcblk0p1 /sdcard"
alias mount_cache="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl11 /cache"
alias mount_dbdata="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl10 /dbdata"

alias make_backup="tar cf $data_archive /data /dbdata"
alias blkrrpart="sfdisk -R /dev/block/mmcblk0"


model=""
current_partition_model=""
debug_mode=0
detect_supported_model() {
	# read the actual MBR
	dd if=/dev/block/mmcblk0 of=/tmp/original.mbr bs=512 count=1

	for x in /res/mbr_samsung/* /res/mbr_voodoo/* ; do
		if cmp $x /tmp/original.mbr; then
			model=`basename $x`
			continue
		fi
	done

	log "model detected: $model"
}

set_partitions() {
	case $1 in
		samsung)
			if test "$current_partition_model" != "samsung"; then
				cat /res/mbr_samsung/$model > /dev/block/mmcblk0
				log "set Samsung partitions"
				blkrrpart 
			fi
		;;
		voodoo)
			if test "$current_partition_model" != "voodoo"; then
				cat /res/mbr_voodoo/$model > /dev/block/mmcblk0
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
	# 5 first MB
	bunzip2 -c $protect_image \
		| dd ibs=1024 count=5k of=/dev/block/mmcblk0p2
	# 10MB around the 220MB limit
	bunzip2 -c $protect_image \
		| dd ibs=1024 obs=1024 skip=215k seek=215k count=10k \
		of=/dev/block/mmcblk0p2
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
	set_partitions voodoo
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
	log="Voodoo: $1"
	echo -e "\n  ###  $log\n" >> /init.log
	echo `date '+%Y-%m-%d %H:%M:%S'` $log >> /voodoo.log
}

say() {
	madplay -A -4 -o wave:- "/res/voices/$1.mp3" | \
		 aplay -Dpcm.AndroidPlayback_Speaker --buffer-size=4096
}

letsgo() {
	# paranoid security: prevent any data leak
	rm $data_archive
	# dump logs to the sdcard
	mount_sdcard
	# create the Voodoo dir in sdcard if not here already
	if test -f /sdcard/Voodoo; then
		rm /sdcard/Voodoo
	fi
	mkdir /sdcard/Voodoo

	log "running init !"

	if test $debug_mode; then
		# copy some logs in it to help beta debugging
		mkdir /sdcard/Voodoo/logs
		
		cat /voodoo.log >> /sdcard/Voodoo/logs/voodoo.txt
		echo >> /sdcard/Voodoo/logs/voodoo.txt
		
		cp /init.log /sdcard/Voodoo/logs/init-"`date '+%Y-%m-%d_%H-%M-%S'`".txt
	else
		# we are not in debug mode, let's wipe stuff to free some MB of memory !
		rm -r /usr
		rm -r /res/voices
		rm -r /res/mbr*
		# clean debugs logs too
		rm -r /sdcard/Voodoo/logs
	fi

	umount /sdcard
	
	exec /sbin/init
}

# proc and sys are  used 
mount -t proc proc /proc
mount -t sysfs sys /sys


# create used devices nodes
mkdir /dev/block
mkdir /dev/snd

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
		letsgo
	fi
fi
umount /cache



# first : read instruction from sdcard and do it !
mount_sdcard

# debug mode detection
if test `find /sdcard/Voodoo/ -iname 'enable*debug*' | wc -l` -ge 1 ; then
	ln -sf init-debug.rc init.rc
	debug_mode=1
else
	ln -sf init-standard.rc init.rc
fi



if test `find /sdcard/Voodoo/ -iname 'disable*lagfix*' | wc -l` -ge 1 ; then
	umount /sdcard
	
	if ext4_check; then

		log "lag fix disabled and ext4 detected"
		say "to-rfs"
		# ext4 partition detected, let's convert it back to rfs :'(
		# mount ressources
		set_partitions voodoo
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
		make_backup
		
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

	compatibility_hacks lagfix-disabled
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
		make_backup
	else
		# something's wrong :(
		log "error: protection file present in rfs but no ext4 data"
	fi
	
	# umount mmcblk0 ressources
	umount /sdcard
	umount /data
	
	# write the fake protection file on mmcblk0p2, just in case
	log "write the fake protection file on mmcblk0p2, just in case" 
	bunzip2 -c $protect_image \
		| dd ibs=1024 count=5k of=/dev/block/mmcblk0p2
	
	# set our partitions back 
	set_partitions voodoo

	# build the ext4 filesystem
	log "build the ext4 filesystem"
	
	# (empty) /etc/mtab is required for this mkfs.ext4
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

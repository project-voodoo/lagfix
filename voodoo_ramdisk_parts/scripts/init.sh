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

# log the script execution
exec > /init.log 2>&1

set -x
PATH=/bin:/sbin:/usr/bin/:/usr/sbin:/voodoo/scripts:/system/bin

sdcard='/tmp/sdcard'
sdcard_ext='/tmp/sdcard_ext'
data_archive="$sdcard/voodoo_user-data.cpio"

alias mount_data_ext4="mount -t ext4 -o noatime,nodiratime /dev/block/mmcblk0p4 /data"
alias mount_data_rfs="mount -t rfs -o nosuid,nodev,check=no /dev/block/mmcblk0p2 /data"
alias mount_cache="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl11 /cache"
alias mount_dbdata="mount -t rfs -o nosuid,nodev,check=no /dev/block/stl10 /dbdata"
alias check_dbdata="fsck_msdos -y /dev/block/stl10"

alias mount_sdcard="mount -t vfat -o utf8 /dev/block/mmcblk0p1 $sdcard"
alias mount_sdcard_ext="mount -t vfat -o utf8 /dev/block/mmcblk1 $sdcard_ext"

alias make_backup="find /data /dbdata | cpio -H newc -o > $data_archive"
alias blkrrpart="hdparm -z /dev/block/mmcblk0"

debug_mode=1

load_stage() {
	# don't reload a stage already in memory
	if ! test -f /tmp/stage$1_loaded; then
		case $1 in
			2)
				stagefile="/voodoo/stage2.cpio.xz"
				if test -f $stagefile; then
					# this stage is in ramdisk. no security check
					log "load stage2"
					xzcat $stagefile | cpio -div
				else
					log "no stage2 to load"
				fi
			;;
			*)
				# give the option to load without signature
				# from the ramdisk itself
				# useful for testing and when size don't matter
				if test -f /voodoo/stage$1.cpio.xz; then
					log "load stage $1 from ramdisk"
					xzcat /voodoo/stage$1.cpio.xz | cpio -div
				else

					stagefile="$sdcard/Voodoo/resources/stage$1.cpio.xz"

					# load the designated stage after verifying it's
					# signature to prevent security exploit from sdcard
					if test -f $stagefile; then
						signature=`sha1sum $stagefile | cut -d' ' -f 1`
						for x in `cat /voodoo/signatures/$1`; do
							if test "$x" = "$signature"  ; then
								log "load stage $1 from SD"
								xzcat $stagefile | cpio -div
								break
							fi
						done
						log "stage $1 not loaded, signature mismatch"
						retcode=1
					fi
					log "stage $1 not loaded, stage file don't exist"
					retcode=1
					
				fi

			;;
		esac
		> /tmp/stage$1_loaded
	fi
	return $retcode
}

detect_supported_model() {
	# read the actual MBR
	dd if=/dev/block/mmcblk0 of=/tmp/original.mbr bs=512 count=1

	for x in /voodoo/mbrs/samsung/* /voodoo/mbrs/voodoo/* ; do
		if cmp $x /tmp/original.mbr; then
			model=`echo $x | /bin/cut -d \/ -f5`
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
	# clean the rests of the previous Ext4 with zeros
	dd if=/dev/zero of=/dev/block/mmcblk0p2 bs=1024 seek=$((215*1024)) count=$((1024*10))
	
	# format stock data partition as RFS using samsung utility
	/system/bin/fat.format -S 4096 -s 4 /dev/block/mmcblk0p2
	
	# mount the freshly formatted RFS partition and fill it by the protection_file
	mount_data_rfs
	# FIXME: use the real maximum size available
	dd if=/dev/zero of=/data/protection_file bs=1024 count=1
	umount /data
}

check_free() {
	# FIXME: add the check if we have enough space based on the
	# space lost with Ext4 conversion with offset
	
	# read free space on internal SD
	target_free=`df $sdcard | cut -d' ' -f 6 | cut -d K -f 1`

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
		umount /data

		mount_sdcard
		say "data-wiped"
		umount $sdcard
		
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
	if load_soundsystem; then 
		# play !
		madplay -A -4 -o wave:- "/voodoo/voices/$1.mp3" | \
			 aplay -Dpcm.AndroidPlayback_Speaker --buffer-size=4096
	 fi
}

load_soundsystem() {
	# load alsa libs & players
	load_stage 3-sound

	# cache the voices from the SD to the ram
	# with a size limit to prevent filling memory security expoit
	if ! test -d /voodoo/voices; then
		if test -d $sdcard/Voodoo/resources/voices/; then
			if test "`du -s $sdcard/Voodoo/resources/voices/ | cut -d \/ -f1`" -le 1024; then
				# copy the voices, using cpio as a "cp" replacement (shrink)
				cd $sdcard/Voodoo/resources
				find voices/ | cpio -p /voodoo
				cd /
				log "voices loaded"
			else
				log "error, voice diretory strangely big"
				retcode=1
			fi
		else
			log "no voice directory, silent mode"
			retcode=1
		fi
	fi
	return $retcode
}

letsgo() {
	# restore stock partitions
	set_partitions samsung
	# paranoid security: prevent any data leak
	test -f $data_archive && rm -v $data_archive
	# dump logs to the sdcard
	mount_sdcard
	# create the Voodoo dir in sdcard if not here already
	test -f $sdcard/Voodoo && rm $sdcard/Voodoo
	mkdir $sdcard/Voodoo 2>/dev/null

	log "running init !"

	if test $debug_mode = 1; then
		# copy some logs in it to help debugging
		mkdir $sdcard/Voodoo/logs 2>/dev/null

		
		cat /voodoo.log >> $sdcard/Voodoo/logs/voodoo.txt
		echo >> $sdcard/Voodoo/logs/voodoo.txt
		
		init_log_filename=init-"`date '+%Y-%m-%d_%H-%M-%S'`".txt
		cat /init.log > $sdcard/Voodoo/logs/$init_log_filename

		# copy logs also on external SD if available
		if mount_sdcard_ext; then
			mkdir $sdcard_ext/Voodoo-logs 2>/dev/null
			cat /init.log > $sdcard_ext/Voodoo-logs/$init_log_filename
			umount $sdcard_ext
		fi

	else
		# we are not in debug mode, let's wipe stuff to free some MB of memory !
		rm -r /voodoo
		# clean now broken symlinks
		rm /bin /usr
		# clean debugs logs too
		rm -r $sdcard/Voodoo/logs 2>/dev/null
	fi

	umount $sdcard
	# set the etc to Android standards
	rm /etc
	# on Froyo ramdisk, there is no etc to /etc/system symlink anymore
	
	# remove our tmp directory
	# FIXME
	#rm -r /tmp
	
	umount /system
	
	# run Samsung's init and disappear
	exec /init_samsung
}

# STAGE 1

# proc and sys are  used 
mount -t proc proc /proc
mount -t sysfs sys /sys

# create used devices nodes
create_devices.sh

# insmod required modules
insmod /lib/modules/fsr.ko
insmod /lib/modules/fsr_stl.ko
insmod /lib/modules/rfs_glue.ko
insmod /lib/modules/rfs_fat.ko

# new in beta5, using /system
mount -t rfs -o ro,check=no /dev/block/stl9 /system 

# use Voodoo etc during the script
ln -s voodoo/root/etc /etc

# make a temporary tmp directory ;)
mkdir /tmp
mkdir /tmp/sdcard
mkdir /tmp/sdcard_ext

# we will need these directories
mkdir /cache 2> /dev/null
mkdir /dbdata 2> /dev/null 
mkdir /data 2> /dev/null 

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
if test "`find $sdcard/Voodoo/ -iname 'enable*debug*'`" != "" ; then
#	echo "service adbd_voodoo_debug /sbin/adbd" >> /init.rc
#	echo "	root" >> /init.rc
#	echo "	enabled" >> /init.rc
	debug_mode=1
fi


if test "`find $sdcard/Voodoo/ -iname 'disable*lagfix*'`" != "" ; then
	umount $sdcard
	
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
		umount $sdcard
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
		umount $sdcard

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
umount $sdcard

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
	umount $sdcard
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
	umount $sdcard
	
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

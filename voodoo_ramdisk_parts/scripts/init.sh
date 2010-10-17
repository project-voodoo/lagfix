#!/bin/sh
###############################################################################
#                                                                             #
#    Voodoo lagfix for Samung Galaxy S                                        #
#                                                                             #
#    http://project-voodoo.org/                                               #
#                                                                             #
#    Devices supported and tested :                                           #
#      o Galaxy S international - GT-I9000 8GB and 16GB                       #
#      o Bell Vibrant GT-I9000B                                               #
#      o T-Mobile Vibrant                                                     #
#      o AT&T Captivate                                                       #
#      o Verizon Fascinate                                                    #
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
exec >> /voodoo_init.log 2>&1

PATH=/bin:/sbin:/usr/bin/:/usr/sbin:/voodoo/scripts:/system/bin
export LD_LIBRARY_PATH=/voodoo/root/libs:/voodoo/root/usr/libs:/system/lib:/lib

sdcard='/voodoo/tmp/sdcard'
sdcard_ext='/voodoo/tmp/sdcard_ext'
data_archive="$sdcard/voodoo_user-data.cpio"

dbdata_partition="/dev/block/stl10"

alias check_dbdata="fsck_msdos -y $dbdata_partition"
alias make_backup="find /data /dbdata | cpio -H newc -o > $data_archive"


debug_mode=1

mount_() {
	case $1 in
		cache)
			mount -t rfs -o nosuid,nodev,check=no /dev/block/stl11 /cache
		;;
		dbdata)
			mount -t rfs -o nosuid,nodev,check=no $dbdata_partition /dbdata
		;;
		cache)
			mount -t rfs -o nosuid,nodev,check=no /dev/block/stl11 /cache
		;;
		data_ext4)
			mount -t ext4 -o noatime,nodiratime,barrier=0,noauto_da_alloc $data_partition /data
		;;
		data_rfs)
			mount -t rfs -o nosuid,nodev,check=no $data_partition /data
		;;
		sdcard)
			mount -t vfat -o utf8 $sdcard_partition $sdcard
		;;
		sdcard_ext)
			mount -t vfat -o utf8 $sdcard_ext_partition $sdcard_ext
		;;
	esac
}

load_stage() {
	# don't reload a stage already in memory
	if ! test -f /voodoo/tmp/stage$1_loaded; then
		case $1 in
			2)
				stagefile="/voodoo/stage2.cpio.lzma"
				if test -f $stagefile; then
					# this stage is in ramdisk. no security check
					log "load stage2"
					lzcat $stagefile | cpio -div
				else
					log "no stage2 to load"
				fi
			;;
			*)
				# give the option to load without signature
				# from the ramdisk itself
				# useful for testing and when size don't matter
				if test -f /voodoo/stage$1.cpio.lzma; then
					log "load stage $1 from ramdisk"
					lzcat /voodoo/stage$1.cpio.lzma | cpio -div
				else

					stagefile="$sdcard/Voodoo/resources/stage$1.cpio.lzma"

					# load the designated stage after verifying it's
					# signature to prevent security exploit from sdcard
					if test -f $stagefile; then
						signature=`sha1sum $stagefile | cut -d' ' -f 1`
						for x in `cat /voodoo/signatures/$1`; do
							if test "$x" = "$signature"  ; then
								log "load stage $1 from SD"
								lzcat $stagefile | cpio -div
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
		> /voodoo/tmp/stage$1_loaded
	fi
	return $retcode
}

detect_supported_model_and_setup_device_names() {
	 # read the actual MBR
	dd if=/dev/block/mmcblk0 of=/voodoo/tmp/original.mbr bs=512 count=1

	for x in /voodoo/mbrs/* ; do
		if cmp $x /voodoo/tmp/original.mbr; then
			model=`echo $x | /bin/cut -d \/ -f4`
			break
		fi
	done

	if test $model != ""; then 
		log "model detected: $model"
		# source the config file with setup data_partition, 
		# sdcard_partition and sdcard_ext_partition
		. "/voodoo/configs/devices_$model"
	else
		return 1
	fi
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

detect_valid_ext4_filesystem() {
	log "ext4 filesystem detection"
	if test "`echo $(blkid $data_partition) | cut -d' ' -f3 \
		| cut -d'"' -f2`" = "ext4"; then
		# blkid find an ext4 partition. but is it real ?
		# if the data partition mounts as rfs, it means
		# that this ext4 partition is just lost bits still here
		if mount_ data_rfs; then
			log "ext4 bits found but from an invalid and corrupted filesystem"
			return 1
		fi
		log "ext4 filesystem detected"
		return 0
	fi
	log "no ext4 filesystem detected"
	return 1
}

wipe_data_filesystem() {
	# ext4 is very hard to wipe due to it's superblock which provide
	# much security, so we wipe the start of the partition (3MB)
	# wich does enouch to prevent blkid to detect Ext4.
	# RFS is also seriously hit by 3MB of zeros ;)
	dd if=/dev/zero of=$data_partition bs=1024 count=$((3 * 1024))
	sync
}

restore_backup() {
	# clean any previous false dbdata partition
	rm -r /dbdata/*
	umount /dbdata
	check_dbdata
	mount_ dbdata
	# extract from the backup,
	# with dirty workaround to fix battery level inaccuracy
	# then remove the backup file if everything went smooth
	cpio -div < $data_archive && rm $data_archive
	rm /data/system/batterystats.bin
}

log() {
	log="Voodoo: $1"
	echo -e "\n  ###  $log\n" >> /voodoo_init.log
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
	
	# paranoid security: prevent any data leak
	test -f $data_archive && rm -v $data_archive
	# dump logs to the sdcard
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
		cat /voodoo_init.log > $sdcard/Voodoo/logs/$init_log_filename

		# copy logs also on external SD if available
		if mount_ sdcard_ext; then
			mkdir $sdcard_ext/Voodoo-logs 2>/dev/null
			cat /voodoo_init.log > $sdcard_ext/Voodoo-logs/$init_log_filename
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

# using what /system partition has to offer
mount -t rfs -o rw,check=no /dev/block/stl9 /system

# make a temporary tmp directory ;)
mkdir /tmp
mkdir /voodoo/tmp/sdcard
mkdir /voodoo/tmp/sdcard_ext

# detect the model using the system build.prop
if ! detect_supported_model_and_setup_device_names; then
	# the hardware model is unknown
	log "model not detected"
	exec /init_samsung
fi

# mounting also the internal sdcard
mount_ sdcard

# use Voodoo etc during the script
ln -s voodoo/root/etc /etc

# we will need these directories
mkdir /cache 2> /dev/null
mkdir /dbdata 2> /dev/null 
mkdir /data 2> /dev/null 

# copy the sound configuration
cat /system/etc/asound.conf > /etc/asound.conf

# unpack myself : STAGE 2
load_stage 2

# detect the MASTER_CLEAR intent command
# this append when you choose to wipe everything from the phone settings,
# or when you type *2767*3855# (Factory Reset, datas + SDs wipe)
mount_ cache
if test -f /cache/recovery/command; then

	if test `cat /cache/recovery/command | cut -d '-' -f 3` = 'wipe_data'; then
		log "MASTER_CLEAR mode"
		say "factory-reset"
		# if we are in this mode, we still have to wipe ext4 partition start
		wipe_ext4
		umount /cache
		letsgo
	fi
fi
umount /cache


# debug mode detection
if test "`find $sdcard/Voodoo/ -iname 'enable*debug*'`" != "" ; then
	echo "ro.secure=0" >> default.prop
	echo "ro.debuggable=0" >> default.prop
	echo "persist.service.adb.enable=1" >> default.prop
	debug_mode=1
fi


if test "`find $sdcard/Voodoo/ -iname 'disable*lagfix*'`" != "" ; then
	
#	if detect_valid_ext4_filesystem; then

		log "lag fix disabled and Ext4 detected"
		# ext4 partition detected, let's convert it back to rfs :'(
		# mount resources
		mount_ data_ext4
		mount_ dbdata
		say "to-rfs"
		
		log "run backup of Ext4 /data"
		
		# check if there is enough free space for migration or cancel
		# and boot
		if ! check_free; then
			log "not enough space to migrate from ext4 to rfs"
			say "cancel-no-space"
			mount_ data_ext4
			echo "yes" > /voodoo/tmp/voodoo_data_mounted
			letsgo
		fi
		
		say "step1"&
		make_backup
		
		# umount data because we will wipe it
		umount /data

		# wipe Ext4 filesystem
		log "wipe Ext4 filesystem before formatin $data_partition as RFS"
		wipe_data_filesystem

		# use newfs_msdos instead of fat.format which wouldn't work
		# here for some obscure reason
		#fat.format.real -v -F 32 -S 4096 -s 4  $data_partition
		# FIXME : find options to replicate fat.format behavior
		newfs_msdos $data_partition

		# restore the data archived
		log "restore backup on rfs /data"
		say "step2"
		mount_ data_rfs
		restore_backup
		
		umount /dbdata

		say "success"

	else

		# in this case, we did not detect any valid ext4 partition
		# hopefully this is because $data_partition contains a valid rfs /data
		log "lag fix disabled, rfs present"
		log "mount /data as rfs"
		mount_ data_rfs

	fi

	# now we know that /data is in RFS anyway. let's fire init !
	letsgo

fi

# Voodoo lagfix is enabled
# detect if the data partition is in ext4 format
log "lag fix enabled"
if ! detect_valid_ext4_filesystem ; then

	log "no valid ext4 partition detected"

	# no ext4 filesystem detected, we will convert to ext4
	# mount resources we need
	log "mount resources to backup"
	mount_ data_rfs
	mount_ dbdata
	say "to-ext4"

	# check if there is enough free space for migration or cancel
	# and boot
	if ! check_free; then
		log "not enough space to migrate from rfs to ext4"
		say "cancel-no-space"
		mount_ data_rfs
		letsgo
	fi

	# run the backup operation
	log "run the backup operation"
	make_backup
	
	# umount data because the partition will be wiped
	umount /data
	
	# wipe the data partition filesystem, just in case
	log "wipe previous RFS filesystem $data_partition" 
	wipe_data_filesystem
	
	# build the ext4 filesystem
	log "build the ext4 filesystems"
	

	# Ext4 DATA 
	# (empty) /etc/mtab is required for this mkfs.ext4
	cat /etc/mke2fs.conf
	mkfs.ext4 -F -O sparse_super $data_partition
	# force check the filesystem after 100 mounts or 100 days
	tune2fs -c 100 -i 100d -m 0 $data_partition
	mount_ data_ext4
	echo "yes" > /voodoo/tmp/voodoo_data_mounted

	# restore the data archived
	say "step2"
	restore_backup

	# clean all these mounts
	umount /dbdata
	say "success"&

else

	# seems that we have a ext4 partition ;) just mount it
	log "valid ext4 detected, mounting ext4 /data !"
	e2fsck -p $data_partition
	mount_ data_ext4
	echo "yes" > /voodoo/tmp/voodoo_data_mounted

fi

# run Samsung's Android init
letsgo

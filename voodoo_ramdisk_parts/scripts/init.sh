#!/bin/sh
###############################################################################
#                                                                             #
#    Voodoo lagfix for Samung Galaxy S                                        #
#                                                                             #
#    http://project-voodoo.org/                                               #
#                                                                             #
#    Devices supported and tested :                                           #
#      o Galaxy S international - GT-I9000 8GB and 16GB                       #
#      o Galaxy S GT-I9000T                                                   #
#      o Bell Vibrant GT-I9000M                                               #
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

PATH=/bin:/sbin:/usr/bin/:/usr/sbin:/voodoo/scripts:/system/bin

sdcard='/voodoo/tmp/sdcard'

# load partition config common to every model
. /voodoo/configs/partitions

# load functions
. /voodoo/scripts/init_functions.sh

# enable this for development
#debug_mode=1


# STAGE 1

# proc and sys are  used 
mount -t proc proc /proc
mount -t sysfs sys /sys

# insmod required modules
insmod /lib/modules/fsr.ko
insmod /lib/modules/fsr_stl.ko
insmod /lib/modules/rfs_glue.ko
insmod /lib/modules/rfs_fat.ko

# insmod Ext4 modules for injected ramdisks
test -f /lib/modules/jbd2.ko && insmod /lib/modules/jbd2.ko
test -f /lib/modules/ext4.ko && insmod /lib/modules/ext4.ko

# create the voodoo etc symlink, required for e2fsprogs, alsa..
ln -s /voodoo/root/etc etc

# detect the model using the system build.prop
if ! detect_supported_model_and_setup_partitions; then
	# the hardware model is unknown
	log "model not detected"
	# try to attempt a boot through the standard procedure
	letsgo
fi

# find what we got
detect_all_filesystems

# using what /system partition has to offer
mount_ system
# copy the sound configuration
cp /system/etc/asound.conf /etc/asound.conf


# we will need these directories
mkdir /cache 2> /dev/null
mkdir /dbdata 2> /dev/null 
mkdir /data 2> /dev/null 


# unpack myself : STAGE 2
load_stage 2

# debug mode detection
if test "`find $sdcard/Voodoo/ -iname 'enable*debug*'`" != "" || test "$debug_mode" = 1 ; then
	log "debug mode enabled"

	# TODO : rewrite the same thing cleaner
	# force enabling very powerful debug tools (and yes, root from adb !)
	mv default.prop default.prop-stock
	echo "# Voodoo lagfix: debug mode enabled" >> default.prop
	echo "ro.secure=0" >> default.prop
	echo "ro.allow.mock.location=0" >> default.prop
	# echo "ro.debuggable=1" >> default.prop
	echo "persist.service.adb.enable=1" >> default.prop
	cat  default.prop-stock >> default.prop
	rm default.prop-stock

	debug_mode=1
fi

if test "`find $sdcard/Voodoo/ -iname 'disable*lagfix*'`" != "" ; then
	lagfix_enabled=0
	log "lagfix disabled"
else
	log "lagfix enabled"
	lagfix_enabled=1
fi


if in_recovery; then

	log "in recovery boot mode"

	# detect the MASTER_CLEAR intent command
	# this append when you choose to wipe everything from the phone settings,
	# or when you type *2767*3855# (Factory Reset, datas + SDs wipe)
	mount_ cache

	if test -f /cache/recovery/command; then

		if test `cat /cache/recovery/command | cut -d '-' -f 3` = 'wipe_data'; then
			log "MASTER_CLEAR mode"
			say "factory-reset"
			# if we are in this mode, we still have to wipe Ext4 partition start
			rfs_format data

			convert cache $cache_partition $cache_fs rfs && cache_fs=rfs
			convert dbdata $dbdata_partition $dbdata_fs rfs && dbdata_fs=rfs
		
			letsgo
		fi
	
	fi

	if test -f /cache/update.zip && test -f /cache/recovery/command; then

		log "CWM Recovery Mode"
		log "recovery command: `cat /cache/recovery/command`"
		if test -f /cache/recovery/extendedcommand; then
			log "CWM extended command: `cat /cache/recovery/extendedcommand`"
		fi
		mkdir /voodoo/cwm
		unzip /cache/update.zip -x META-INF/* -d /voodoo/cwm
		
		/voodoo/scripts/cwm_setup.sh
		ln -s /voodoo/scripts/mount_wrapper.sh /sbin/mount
	else
		# stock recovery don't handle /cache or /dbdata in Ext4
		# give them rfs filesystems
		convert cache $cache_partition $cache_fs rfs &&	cache_fs=rfs
		convert dbdata $dbdata_partition $dbdata_fs rfs && dbdata_fs=rfs
	fi
	
	umount /cache
fi

if test "$lagfix_enabled" = 1; then

	if ! in_recovery; then
		convert cache $cache_partition $cache_fs ext4 && cache_fs=ext4
		convert dbdata $dbdata_partition $dbdata_fs ext4 && dbdata_fs=ext4
	fi
	convert data $data_partition $data_fs ext4 && data_fs=ext4
	convert system $system_partition $system_fs ext4 && system_fs=ext4

	mount_ cache
	mount_ dbdata
	mount_ data
	mount_ system
	> /voodoo/run/ext4_enabled

	letsgo
else

	convert data $data_partition $data_fs rfs && data_fs=rfs
	convert cache $cache_partition $cache_fs rfs && cache_fs=rfs
	convert dbdata $dbdata_partition $dbdata_fs rfs && dbdata_fs=rfs
	convert system $system_partition $system_fs rfs && system_fs=rfs
	
	letsgo
fi

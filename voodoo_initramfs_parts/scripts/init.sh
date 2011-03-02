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
#      o USCC Mesmerize                                                       #
#      o Cellular South Showcase                                              #
#      o Verizon Galaxy Tablet                                                #
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

PATH=/bin:/sbin:/usr/bin/:/usr/sbin:/voodoo/bin:/voodoo/scripts:/system/bin

# load configs
. /voodoo/configs/partitions
. /voodoo/configs/shared

# load functions
. /voodoo/scripts/init_functions.sh

# enable this for development
# debug_mode=1


# create the voodoo etc symlink, required for e2fsprogs, alsa..
ln -s /voodoo/root/etc etc


# detect the model using the system build.prop
if ! detect_supported_model_and_setup_partitions; then
	# the hardware model is unknown
	log "model not detected"

	# configure all in RFS
	system_fs='rfs'
	data_fs='rfs'
	dbdata_fs='rfs'
	cache_fs='rfs'

	# try to attempt a boot through the standard procedure
	letsgo
fi


# read if the lagfix is enabled or not
if test "`find /sdcard/Voodoo/ -iname 'disable*lagfix*'`" != "" ; then
	lagfix_enabled=0
	log "option: lagfix disabled"
else
	lagfix_enabled=1
	log "option: lagfix enabled"
fi


# read if the /system conversion is enabled ot not
if test "`find /sdcard/Voodoo/ -iname 'system*as*rfs*'`" != "" ; then
	system_as_rfs=1
	log "option: lagfix will keep /system as RFS"
else
	system_as_rfs=0
	log "option: lagfix is allowed to convert /system to Ext4"
fi


# debug mode detection
if test "`find /sdcard/Voodoo/ -iname 'enable*debug*'`" != "" || test "$debug_mode" = 1 ; then
	log "option: debug mode enabled"

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


# find what we got
detect_all_filesystems


# find kernel version
configure_from_kernel_version


# mount /system so we will be able to use df, fat.format and asound.conf
mount_ system


# we will need these directories
mkdir /cache 2> /dev/null
mkdir /dbdata 2> /dev/null
mkdir /data 2> /dev/null


# workaround the terrible RFS mount bug:
# check if there is a backup of a conversion interrupted by the terrible
# rfs driver bug:
finalize_interrupted_rfs_conversion


# copy the sound configuration
cp /system/etc/asound.conf /etc/asound.conf
cp /system/etc/asound.conf /sdcard/Voodoo/


# unpack myself : STAGE 2
load_stage 2


if in_recovery; then

	log "in recovery boot mode"
	mount_ cache

	if test -f /cache/recovery/command; then
		recovery_command=`cat /cache/recovery/command`
		log "recovery command: $recovery_command"
	fi


	if detect_cwm_recovery; then
		log "CWM Recovery Mode"
		if test -f /cache/recovery/extendedcommand; then
			log "CWM extended command: `cat /cache/recovery/extendedcommand`"
		fi
		
		if test -f /cache/update.zip; then
			mkdir /cwm
			unzip -o /cache/update.zip -x META-INF/* -d /cwm
		fi

		# little help for sdcard mounting
		echo -n "$sdcard_device" > /voodoo/run/sdcard_device

		/voodoo/scripts/cwm_setup.sh
		# setup the mount wrapper
		ln -s /voodoo/scripts/mount_wrapper.sh /sbin/mount
		> /voodoo/run/cwm_enabled

		log_suffix='-CWM-recovery'
		# don't run conversion process if booting into CWM recovery
		umount /cache
		letsgo
	else
		# stock recovery don't handle /cache or /dbdata in Ext4
		# give them rfs filesystems

		rm -rf /cwm
		umount /cache
		log "stock recovery compatibility: make DBDATA: and CACHE: standard RFS"
		convert cache rfs
		convert dbdata rfs
	fi
	
	umount /cache
else
	rm -rf /cwm
fi


if test $lagfix_enabled = 1; then

	if ! in_recovery; then
		convert cache ext4
		convert dbdata ext4
	fi
	convert data ext4
	if test $system_as_rfs = 0; then
		convert system ext4
	else
		convert system rfs
	fi

	letsgo
else

	convert cache rfs
	convert dbdata rfs
	convert data rfs
	convert system rfs
	
	letsgo
fi

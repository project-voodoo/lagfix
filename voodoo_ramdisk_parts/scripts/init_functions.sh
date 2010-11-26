# voodoo lagfix functions

mount_()
{
	case $1 in
		cache)
			if test "$cache_fs" = "ext4"; then
				e2fsck -p $cache_partition
				mount -t ext4 -o noatime,barrier=0,data=writeback$ext4_options $cache_partition /cache
			else
				mount -t rfs -o nosuid,nodev,check=no $cache_partition /cache
			fi
		;;
		dbdata)
			if test "$dbdata_fs" = "ext4"; then
				e2fsck -p $dbdata_partition
				mount -t ext4 -o noatime,barrier=0$ext4_options $dbdata_partition /dbdata
			else
				mount -t rfs -o nosuid,nodev,check=no $dbdata_partition /dbdata
			fi
		;;
		data)
			if test "$data_fs" = "ext4"; then
				e2fsck -p $data_partition
				mount -t ext4 -o noatime,barrier=0$ext4_options $data_partition /data
			else
				mount -t rfs -o nosuid,nodev,check=no $data_partition /data
			fi
		;;
		system)
			if test "$system_fs" = "ext4"; then
				e2fsck -p $system_partition
				mount -t ext4 -o noatime,barrier=0$ext4_options $system_partition /system
			else
				mount -t rfs -o check=no $system_partition /system
			fi
		;;
	esac
}


mount_tmp()
{
	# used during conversions and detection
	mount -t ext4 $1 -o barrier=0,noatime /voodoo/tmp/mnt/ || mount -t rfs -o check=no $1 /voodoo/tmp/mnt/
}

umount_tmp()
{
	umount /voodoo/tmp/mnt
}


log_time()
{
	case $1 in
		start)
			start=`date '+%s'`
		;;
		end)
			end=`date '+%s'`
			log 'time spent: '$(( $end - $start ))'s' 1
		;;
	esac
}


load_stage()
{
	# don't reload a stage already in memory
	if ! test -f /voodoo/run/stage$1_loaded; then
		case $1 in
			2)
				stagefile="/voodoo/stage2.tar.lzma"
				if test -f $stagefile; then
					# this stage is in ramdisk. no security check
					log "load stage2"
					lzcat $stagefile | tar xvf
				else
					log "no stage2 to load"
				fi
			;;
			*)
				# give the option to load without signature
				# from the ramdisk itself
				# useful for testing and when size don't matter
				if test -f /voodoo/stage$1.tar.lzma; then
					log "load stage $1 from ramdisk"
					lzcat /voodoo/stage$1.tar.lzma | tar xvf
				else

					stagefile="$sdcard/Voodoo/resources/stage$1.tar.lzma"

					# load the designated stage after verifying it's
					# signature to prevent security exploit from sdcard
					if test -f $stagefile; then
						retcode=1
						signature=`sha1sum $stagefile | cut -d' ' -f 1`
						for x in `cat /voodoo/signatures/stage$1`; do
							if test "$x" = "$signature"  ; then
								retcode=0
								log "load stage $1 from SD"
								lzcat $stagefile | tar xv
								break
							fi
						done
					fi
					test retcode = 1 && log "stage $1 not loaded, stage file don't exist"
				fi

			;;
		esac
		> /voodoo/run/stage$1_loaded
	fi
	return $retcode
}


detect_supported_model_and_setup_partitions()
{
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
		
		# fascinate is different here
		if test "$model" = 'fascinate'; then
			data_partition='/dev/block/mmcblk0p1'
			sdcard_device='/dev/block/mmcblk1p1'
		else
		# for every other model
			data_partition='/dev/block/mmcblk0p2'
			sdcard_device='/dev/block/mmcblk0p1'
		fi
		echo "data_partition='$data_partition'" >> /voodoo/configs/partitions

	else
		return 1
	fi
}


detect_fs_on()
{
	resource=$1
	partition=$2
	log "filesystem detection on $resource:"
	if tune2fs -l $partition 1>&2; then
		# we found an ext2/3/4 partition. but is it real ?
		# if the data partition mounts as rfs, it means
		# that this Ext4 partition is just lost bits still here
		if mount -t rfs -o ro,check=no $partition /voodoo/tmp/mnt data; then
			log "RFS on $partition: Ext4 bits found but from an invalid and corrupted filesystem" 1
			umount_tmp
			echo rfs
			return
		fi
		log "Ext4 on $partition" 1
		echo ext4
		return
	fi
	log "RFS on $partition" 1
	echo rfs
}


detect_all_filesystems()
{
	system_fs=`detect_fs_on system $system_partition`
	dbdata_fs=`detect_fs_on dbdata $dbdata_partition`
	cache_fs=`detect_fs_on cache $cache_partition`
	data_fs=`detect_fs_on data $data_partition`
}


configure_from_kernel_version()
{
	if test "`cat /proc/version | cut -d'.' -f 3`" = 32; then
		kversion="2.6.32"
		ext4_options=",noauto_da_alloc"
	fi
}


log()
{
	indent=""
	test "$2" = 1 && indent="    "
	test "$2" = 2 && indent="        "
	echo "`date '+%Y-%m-%d %H:%M:%S'` $indent $1" >> /voodoo/logs/voodoo_log.txt
}


say()
{
	test "$silent" = 1 && return
	# sound system lazy loader
	if load_soundsystem; then 
		# play !
		madplay -A -4 -o wave:- "/voodoo/voices/$1.mp3" | \
			 aplay -Dpcm.AndroidPlayback_Speaker --buffer-size=4096
	fi
}


load_soundsystem()
{
	# load alsa libs & players
	load_stage 3-sound

	# cache the voices from the SD to the ram
	# with a size limit to prevent filling memory security expoit
	if ! test -d /voodoo/voices; then
		if test -d $sdcard/Voodoo/resources/voices/; then
			if test "`du -s $sdcard/Voodoo/resources/voices/ | cut -d \/ -f1`" -le 1024; then
				# copy the voices (no cp command, use cat)
				cp -r $sdcard/Voodoo/resources/voices /voodoo/
				log "voices loaded"
			else
				log "ERROR: voice diretory strangely big"
				retcode=1
			fi
		else
			log "no voice directory, silent mode"
			retcode=1
		fi
	fi
	return $retcode
}


verify_voodoo_install()
{
	for x in /sbin/fat.format /system/bin/fat.format; do
		# manage Froyo & Eclair
		test "$x" = "/sbin/fat.format" && prefix="/sbin" || prefix="/system/bin"
		test -x "$prefix/fat.format" && log "manage fat.format in $prefix" || continue

		# if the wrapper is not the same as the one in this ramdisk, we install it
		if ! cmp /voodoo/system_scripts/fat.format_wrapper.sh "$prefix/fat.format_wrapper.sh"; then
			cp /voodoo/system_scripts/fat.format_wrapper.sh "$prefix/fat.format_wrapper.sh"
			log "fat.format wrapper installed in $prefix"
		else
			log "fat.format wrapper already installed in $prefix"
		fi

		# now, check the validity of the symlink
		if ! test -L "$prefix/fat.format" && test -x "$prefix/fat.format_wrapper.sh" ; then

			# if fat.format is not a symlink, it means that it's
			# Samsung's binary. Let's rename it
			mv "$prefix/fat.format" "$prefix/fat.format.real"
			ln -s fat.format_wrapper.sh "$prefix/fat.format"
			log "fat.format renamed to fat.format.real & symlink created to fat.format_wrapper.sh"
		fi
	done
}


in_recovery()
{
	test "`cut -d' ' -f 1 /proc/cmdline`" = "bootmode=2"
}


detect_cwm_recovery()
{
	if  test -f /cache/update.zip && test "$recovery_command" = "--update_package=CACHE:update.zip"; then
			# check if this is a real CWM update.zip

			log "analyze CACHE:update.zip to see if it's CWM recovery"
			testdir="/voodoo/tmp/cwm-detection"
			mkdir $testdir
			unzip /cache/update.zip sbin/recovery sbin/adbd -d /voodoo/tmp/cwm-detection

			if test -f $testdir/sbin/recovery && test -f $testdir/sbin/adbd; then
				rm -rf $testdir
				log "CWM recovery found"
				return 0
			fi
	else
		if test -d /cwm && test -f /cwm/sbin/recovery && test -f /cwm/sbin/adbd; then
			# CWM is already present in this ramdisk
			# run it only if we are not supposed to run other commands
			# like CSC updates or OTAs
			log "CWM recovery present in /cwm"
			if test "$recovery_command" = ''; then
				log "no recovery command specified, Ok for CWM"
				return 0
			else
				log "recovery command specified, aborting CWM launch"
				return 1
			fi
		fi
	fi
	# no CWM detected
	return 1
}


enough_space_to_convert()
{
	resource=$1
	log "check space for $resource:" 1
	
	# mount resource to check for space, except if it's system (already mounted)
	test $resource != system && mount_ $resource

	# read free space on internal SD
	target_free=$((`df $sdcard | cut -d' ' -f 6 | cut -d K -f 1` / 1024 ))

	# read space used by data we need to save
	space_needed=$((`df /$resource | cut -d' ' -f 4 | cut -d K -f 1` / 1024 ))

	log "free space:   $target_free MB" 2
	log "space needed: $space_needed MB" 2

	# more than 100MB on /data, talk to the user
	test $space_needed -gt 100 && say "wait"

	# umount the resource if it's not /system
	test "$resource" != "system" && umount /$resource

	# ask for 10% more free space for security reasons
	test $target_free -ge $(( $space_needed + $space_needed / 10))
}


rfs_format()
{
	log "format $1 as RFS using Android init + a fake init.rc to run fat.format" 1
	# communicate with the formatter script
	echo "$1" > /voodoo/run/rfs_format_what
	
	# save real init .rc files
	mv *.rc /voodoo/tmp/

	# create rc for every condition
	cp /voodoo/scripts/rfs_formatter.rc init.rc
	ln -s init.rc recovery.rc
	ln -s init.rc fota.rc
	ln -s init.rc lpm.rc
	
	# run init that will run the actual format script
	/init_samsung
	umount /dev/pts
	umount /dev
	echo >> $log_dir/rfs_formatter_log.txt

	# let's restore the original .rc files
	rm *.rc
	mv /voodoo/tmp/*.rc ./
}


ext4_format()
{
	if test $resource = "data"; then
		journal_size=12
		features='sparse_super,'
	else
		journal_size=4
		features=''
	fi
	mkfs.ext4 -F -O "$features"^resize_inode -J size=$journal_size -T default $partition
	# force check the filesystem after 100 mounts or 100 days
	tune2fs -c 100 -i 100d -m 0 $partition
}


copy_system_in_ram()
{
	if ! test -d /system_in_ram; then
		# save /system stuff
		log "make a limited copy of /system in ram" 1
		mkdir -p /system_in_ram/bin
		cp	/system/bin/toolbox \
			/system/bin/sh \
			/system/bin/log \
			/system/bin/linker \
			/system/bin/fat.format*  /system_in_ram/bin/

		mkdir -p /system_in_ram/lib/
		cp 	/system/lib/liblog.so \
			/system/lib/libc.so \
			/system/lib/libstdc++.so \
			/system/lib/libm.so \
			/system/lib/libcutils.so /system_in_ram/lib/
		umount /system
		ln -s /system_in_ram/* /system
	fi
}


convert()
{
	resource="$1"
	partition="$2"
	fs="$3"
	dest_fs="$4"
	
	output_fs=$fs

	if test $fs = $dest_fs; then
		log "no need to convert $resource"
		return
	fi
	log "convert $resource ($partition) from $fs to $dest_fs"

	# be sure fat.format is in PATH
	if test "$dest_fs" = "rfs"; then
		fat.format > /dev/null 2>&1
		if test "$?" = 127; then
			log "ERROR: unable to call fat.format: cancel conversion" 1
			return 1
		fi
	fi

	# make sure df is there or cancel conversion
	if ! df > /dev/null 2>&1 ; then
		log "ERROR: unable to call the df command from system, cancel conversion" 1
		say "cancel-no-system"
		return 1
	fi
	if ! enough_space_to_convert $resource; then
		log "ERROR: not enough space to convert $resource" 1
		say "cancel-no-space"
		return 1
	fi
	
	if test "$dest_fs" = "rfs" && test "$resource" = "system"; then
		copy_system_in_ram
		# /system has been unmounted
		remount_system=1
	fi

	log "backup $resource" 1
	say "step1"

	if ! mount_tmp $partition; then
		log "ERROR: unable to mount $partition" 1
		return 1
	fi

	log_time start
	if ! time tar cvf $sdcard/voodoo_"$resource"_conversion.tar /voodoo/tmp/mnt/ | cut -d/ -f4- \
			| tee $log_dir/"$resource"_to_"$dest_fs"_backup_list.txt > /dev/null; then
		log "ERROR: problem during $resource backup, the filesystem must be corrupted" 1
		log "This error comes after an RFS filesystem has been mounted without the standard -o check=no" 1
		if test $fs = rfs; then
			log "Attempting a mount with broken RFS options" 1
			mount -t rfs -o ro $partition /voodoo/tmp/mnt/
			if ! tar cvf $sdcard/voodoo_"$resource"_conversion.tar /voodoo/tmp/mnt/ \
				> $log_dir/"$resource"_backup_list_2.txt; then
				log "Unable to save a correct backup: cancel conversion" 2
				umount_tmp
				return 1
			else
				log "second attempt successful"
			fi
		fi
	fi
	umount_tmp
	log_time end

	log "format $partition" 1
	if test "$dest_fs" = "rfs"; then
		rfs_format $resource
		output_fs=rfs
	else
		test $resource = system && umount /system && remount_system=1
		ext4_format
		output_fs=ext4
	fi

	log "restore $resource" 1
	say "step2"

	if test $output_fs = rfs && test $resource = system; then
		log "reboot to avoid mount failure due to RFS driver bugs"
		reboot -f
	fi

	if ! mount_tmp $partition; then
		log "ERROR: unexpected issue, unable to mount $partition to restore the backup" 1
		umount_tmp
		return 1
	fi

	log_time start
	if ! time tar xvf $sdcard/voodoo_"$resource"_conversion.tar | cut -d/ -f4- \
			| tee $log_dir/"$resource"_to_"$dest_fs"_restore_list.txt >/dev/null; then
		log "ERROR: problem during $resource restore" 1
		umount_tmp
		return 1
	fi
	log_time end
	test "debug_mode" != 1 && rm $sdcard/voodoo_"$resource"_conversion.tar

	umount_tmp

	# remount /system if needed
	test $resource = system && system_fs=$output_fs
	test "$remount_system" = 1 && mount_ system

	# conversion is successful
	return 0
}



finalize_system_rfs_conversion()
{
	# thanks to Mish for the idea

	min_system_size=20480
	system_archive=$sdcard/voodoo_system_conversion.tar
	
	# check if the /system archive is there and is more than 20MB
	if test -f $system_archive; then

		# check if /sytem is empty (or at contains less than 20MB of data)
		if test `du -s /system | cut -d/ -f1` -lt $min_system_size; then
			log "finalize /system conversion to RFS: restore backup"
			rm -rf /system/*
			umount /system

			log_time start
			mount_tmp $system_partition
			if tar xvf $system_archive | cut -d/ -f4- \
				| tee $log_dir/system_rfs_conversion_workaround_restore_list.txt >/dev/null; then
			log_time end
				log "/system backup restored, workaround successful" 1
				rm $system_archive
			else
				mv $system_archive $sdcard/voodoo_system_conversion_failed_restore.tar
				log "/system backup error, unrecoverable error" 1
				log "attempt boot to recovery" 1
				/system/bin/reboot recovery
			fi
			umount_tmp

			mount_ system
		else
			log "found a /system temporary archive but it looks already okay"
			log "$sdcard/voodoo_system_conversion.tar ignored"
			test $debug_mode != 1 && rm $system_archive
		fi
	fi

}



letsgo()
{
	# mount Ext4 partitions
	test $cache_fs = ext4 && mount_ cache && > /voodoo/run/lagfix_enabled
	test $dbdata_fs = ext4 && mount_ dbdata && > /voodoo/run/lagfix_enabled
	test $data_fs = ext4 && mount_ data && > /voodoo/run/lagfix_enabled
	test $system_fs = ext4 && > /voodoo/run/lagfix_enabled

	# free ram
	rm -rf /system_in_ram

	# remove the tarball in maximum compression mode
	rm -f compressed_voodoo_ramdisk.tar.lzma

	verify_voodoo_install

	# if /data is an Ext4 filesystem, it means we need to activate
	# the fat.format wrapper protection
	test "$data_fs" = "ext4" && > /voodoo/run/lagfix_enabled
	
	# run additionnal extensions scripts
	# actually they are sourced so they can use the init functions,
	# resources and variables
	
	if test "`find /voodoo/extensions/ -name '*.sh'`" != "" ; then
		for x in /voodoo/extensions/*.sh; do
			log "running extension: `echo $x | cut -d'/' -f 4`"
			. "$x"
		done
	fi

	log "running init !"

	# Manage logs
	# clean up old logs on sdcard (more than 7 days)
	find $sdcard/Voodoo/logs/ -mtime +7 -delete

	# manage the voodoo_history log
	tail -n 1000 $sdcard/Voodoo/logs/voodoo_history_log.txt > /voodoo/logs/voodoo_history_log.txt
	echo >> /voodoo/logs/voodoo_history_log.txt
	cat /voodoo/logs/voodoo_history_log.txt /voodoo/logs/voodoo_log.txt > $sdcard/Voodoo/logs/voodoo_history_log.txt
	# save current voodoo_log in the sdcard
	cp /voodoo/logs/voodoo_log.txt $log_dir/

	# manage other logs
	cp $log_dir/* /voodoo/logs

	current_log_directory=boot-`date '+%Y-%m-%d_%H-%M-%S'`
	mv $log_dir $sdcard/Voodoo/logs/$current_log_directory
	
	# remove voices from memory
	rm -r /voodoo/voices

	# remove CWM setup files
	rm -rf /cwm

	# set the etc to Android standards
	rm /etc
	# on Froyo ramdisk, there is no etc to /etc/system symlink anymore

	if test "$system_fs" = "rfs"; then
		umount /system
	fi
	
	# exit this main script (the runner will execute samsung_init )
	exit
}


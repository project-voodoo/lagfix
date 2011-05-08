# voodoo lagfix functions

get_partition_for()
{
	# resource partition getter which set a global variable named partition
	case $1 in
		cache)		partition=$cache_partition ;;
		dbdata)		partition=$dbdata_partition ;;
		datadata)	partition=$dbdata_partition ;;
		data)		partition=$data_partition ;;
		system)		partition=$system_partition ;;
	esac
}


get_fs_for()
{
	# resource filesystem getter which set a global variable named fs
	case $1 in
		cache)		fs=$cache_fs ;;
		dbdata)		fs=$dbdata_fs ;;
		datadata)	fs=$dbdata_fs ;;
		data)		fs=$data_fs ;;
		system)		fs=$system_fs ;;
	esac
}


set_fs_for()
{
	# resource filesystem getter which set a global variable named fs
	case $1 in
		cache)	cache_fs=$2 ;;
		dbdata)	dbdata_fs=$2 ;;
		data)	data_fs=$2 ;;
		system)	system_fs=$2 ;;
	esac
}


mount_()
{
	get_partition_for $1
	get_fs_for $1

	if test "$fs" = "ext4"; then
		e2fsck -p $partition
		case $1 in
			# don't care about data safety for cache
			cache)	ext4_data_options=',data=writeback' ;;
			# MoviNAND hardware support barrier, it allows to activate
			# the journal option data=ordered and stay free from corruption
			# even in worst cases
			data)	ext4_data_options=',data=ordered,barrier=1' ;;
			# dbdata device don't support barrier. Delayed allocations
			# are unsafe and must be deactivated
			dbdata)	ext4_data_options=',data=ordered,nodelalloc' ;;
			*)	ext4_data_options=',data=journal' ;;
		esac

		# mount as Ext4
		mount -t ext4 -o noatime,barrier=0$ext4_data_options$ext4_options $partition /$1
	else
		# mount as RFS with standard options
		mount -t rfs -o nosuid,nodev,check=no $partition /$1
	fi
}


mount_tmp()
{
	# used during conversions and detection
	mount -t ext4 $1 -o barrier=0,noatime,data=writeback /voodoo/tmp/mnt/ || mount -t rfs -o check=no $1 /voodoo/tmp/mnt/
}


umount_tmp()
{
	umount /voodoo/tmp/mnt
}


log_time()
{
	case $1 in
		start)
			start=`date '+%s'` ;;
		end)
			end=`date '+%s'`
			log 'time spent: '$(( $end - $start ))' s' 1 ;;
	esac
}


ensure_reboot()
{
	# send a message to the watchdog to be sure we reboot even if #
	# reboot command fails
	# loosely using the watchdog device which is supposed
	# to be managed by a watchdog daemonq
	echo 0 > /dev/watchdog
	# ask to reboot without sync() after a delay of 5s
	/bin/reboot -d 5 -n&
	# trigger reboot with the standard method, may fail when sync() stall
	# because of the RFS driver mount bug
	/bin/reboot -f
}


load_stage()
{
	# don't reload a stage already in memory
	if ! test -f /voodoo/run/stage$1_loaded; then
		case $1 in
			2)
				stagefile="/voodoo/stage2.tar.lzma"
				if test -f $stagefile; then
					# this stage is in initramfs. no security check
					log "load stage2"
					lzcat $stagefile | tar xv
				else
					log "no stage2 to load"
				fi
				;;
			*)
				# give the option to load without signature
				# from the initramfs itself
				# useful for testing and when size don't matter
				if test -f /voodoo/stage$1.tar.lzma; then
					log "load stage $1 from initramfs"
					lzcat /voodoo/stage$1.tar.lzma | tar xv
				else

					stagefile="/sdcard/Voodoo/resources/stage$1.tar.lzma"

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
	# read the actual partition table
	dd if=/dev/block/mmcblk0 of=/voodoo/tmp/partition_table bs=1 skip=446 count=64

	for x in /voodoo/partition_tables/* ; do
		if cmp $x /voodoo/tmp/partition_table; then
			model=`echo $x | /bin/cut -d \/ -f4`
			break
		fi
	done

	if test "$model" != ""; then
		log "model detected: $model"
		
		# fascinate/mesmerize/showcase are different here
		if test "$model" = 'fascinate' || test "$model" = 'mesmerize-showcase' || test "$model" = 'continuum'; then
			data_partition='/dev/block/mmcblk0p1'
			sdcard_device='/dev/block/mmcblk1p1'
		else
		# for every other model
			data_partition='/dev/block/mmcblk0p2'
			sdcard_device='/dev/block/mmcblk0p1'
		fi
		echo "data_partition='$data_partition'" >> /voodoo/configs/partitions

	else
		dd if=/dev/block/mmcblk0 of=/voodoo/run/model_not_supported-mbr.bin bs=512 count=1
		return 1
	fi
}


detect_fs_on()
{
	resource=$1
	get_partition_for $resource
	log "filesystem detection on $resource:"
	if tune2fs -l $partition 1>&2; then
		# we found an ext2/3/4 partition. but is it real ?
		# if the data partition mounts as rfs, it means
		# that this Ext4 partition is just lost bits still here
		log "Ext4 on $partition" 1
		echo ext4
		return
	fi
	log "RFS on $partition" 1
	echo rfs
}


detect_all_filesystems()
{
	system_fs=`detect_fs_on system`
	dbdata_fs=`detect_fs_on dbdata`
	cache_fs=`detect_fs_on cache`
	data_fs=`detect_fs_on data`
}


configure_from_kernel_version()
{
	subversion=`cat /proc/version | cut -d'.' -f 3`
	if test "$subversion" = 32 || test "$subversion" = 35 ; then
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
		madplay --stereo -A -3 -o wave:- "/voodoo/voices/$1.mp3" 2> /dev/null | \
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
		if test -d /sdcard/Voodoo/resources/voices/; then
			if test "`du -s /sdcard/Voodoo/resources/voices/ | cut -d \/ -f1`" -le 1024; then
				# copy the voices (no cp command, use cat)
				cp -r /sdcard/Voodoo/resources/voices /voodoo/
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

		# if the wrapper is not the same as the one in this initramfs, we install it
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
	if test "`cut -d' ' -f 1 /proc/cmdline`" = "bootmode=2"; then
		log_suffix='-recovery'
		return 0
	else
		return 1
	fi
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
			# CWM is already present in this initramfs
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


check_available_space()
{
	log "check space availability for $resource:" 1
	
	# mount resource to check for space, except if it's system (already mounted)
	test $resource != system && mount_ $resource

	# read free space on internal SD
	sdcard_available=$((`stat -f -c "%a * %S / (1024 * 1024)" /sdcard`))

	# read space free on the partition we need to backup
	resource_available=$((`stat -f -c "%a * %S / (1024 * 1024)" /$resource`))

	# read space used by data we need to backup
	resource_used=$(((`stat -f -c "%b * %S / (1024 * 1024)" /$resource`) - $resource_available))

	log "available:        $resource_available MB" 2
	log "used:             $resource_used MB" 2
	log "sdcard available: $sdcard_available MB" 2

	# check if the Ext4 overhead let us enough space
	if test $dest_fs = ext4; then
		log "check Ext4 additionnal disk usage for $resource" 1
		case $resource in
			system)	overhead=1 ;;
			data)	overhead=40 ;;
			dbdata)	overhead=20 ;;
			cache)	overhead=0 ;; # cache? don't care
		esac

		if test $resource_available -lt $overhead; then
			log "$resource partition space usage too high to convert to Ext4" 2
			log "missing: "$(( $overhead - $resource_available ))' MB' 2

			if test $resource = system; then
				log "disabling /system conversion by configuration"
				set_system_as_rfs
			fi
			available_space_error='partition'
			return 2
		else
			log "enough free space on /$resource to convert to Ext4" 2
		fi
	fi

	# umount the resource if it's not /system
	test "$resource" != "system" && umount /$resource

	# ask for 1% more free space for security reasons
	if ! test $sdcard_available -ge $(( $resource_used + $resource_used / 100)); then
		available_space_error='sdcard'
		return 1
	fi
	return 0
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
	common_mkfs_ext4_options='^resize_inode,^ext_attr,^huge_file'
	case $resource in
		# tune system inode number to fit available space in RFS and Ext4
		system)	mkfs_options="-O $common_mkfs_ext4_options,^has_journal -N 7500"  ;;
		cache)	mkfs_options="-O $common_mkfs_ext4_options -J size=4 -N 800"  ;;
		data)	mkfs_options="-O $common_mkfs_ext4_options -J size=32" ;;
		dbdata)	mkfs_options="-O $common_mkfs_ext4_options -J size=16" ;;
	esac
	mkfs.ext4 -F $mkfs_options -T default $partition
	# force check the filesystem after 100 mounts or 100 days
	tune2fs -c 100 -i 100d -m 0 -L $resource $partition
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



build_archive()
{
	rm -rf /voodoo/tmp/mnt/lost+found
	time tar cv /voodoo/tmp/mnt/ 2> $log_dir/"$1"_list.txt \
		| lzop | dd bs=$(( 4096 * 512 )) of=$archive
}


extract_archive()
{
	time dd if=$archive bs=$(( 4096 * 512 )) | lzopcat | tar xv > $log_dir/"$1"_list.txt 2>&1
}


conversion_mount_and_restore()
{
	if ! mount_tmp $partition; then
		log "ERROR: unable to mount $partition to restore the backup" 1
		log "this error is known to happens because of the RFS driver mount bug"
		log "reboot and catch the error later"
		umount_tmp
		log_suffix='-RFS-bug-hit'
		manage_logs
		ensure_reboot
		# past here this code is supposed to be *never* executed
		sleep 20
		return 1
	fi

	log_time start
	# archive management
	if ! extract_archive "$resource"_to_"$dest_fs"_restore; then
		log "ERROR: problem during $resource restore" 1
		umount_tmp
		return 1
	fi
	log_time end
}


convert()
{
	resource="$1"
	dest_fs="$2"
	test tell_conversion_happened = '' && tell_conversion_happened=0
	
	# use global getters
	get_partition_for $resource
	get_fs_for $resource

	source_fs=$fs

	if test $source_fs = $dest_fs; then
		log "no need to convert $resource"
		return
	fi

	if test -f /voodoo/run/no_sdcard; then
		# this can happens on Fascinate/Mesmerize/Showcase only
		log "no SD Card is available, cannot proceed to conversion"
		return 1
	fi

	# read the battery level
	if test "$model" = 'fascinate' || test "$model" = 'mesmerize-showcase' || test "$model" = 'continuum'; then
		battery_level=`cat /sys/devices/platform/sec-battery/power_supply/battery/capacity`
	else
		battery_level=`cat /sys/devices/platform/jupiter-battery/power_supply/battery/capacity`
	fi
	log "battery level: $battery_level%"

	if test "$battery_level" -lt 10 && test $resource != cache && test $resource != dbdata; then
		log "battery level too low for /$resource conversion"
		say "low-battery"
		return 1
	fi

	log "convert $resource ($partition) from $source_fs to $dest_fs"

	archive=/sdcard/voodoo_"$resource"_conversion.tar.lzo
	archive_saved=/sdcard/voodoo_"$resource"_conversion_saved.tar.lzo
	rm -f $archive $archive_saved

	# tag the log for easier analysis
	if test $resource = cache || test $resource = dbdata; then
		silent=1
	else
		log_suffix='-conversion'
		silent=0
		say "convert-$resource"
	fi

	# be sure fat.format is in PATH
	if test "$dest_fs" = "rfs"; then
		#  make sure fat.format binary in initramfs is executable
		chmod 750 /sbin/fat.format 2>/dev/null
		fat.format > /dev/null 2>&1
		returncode=$?
		if test "$returncode" = 127 || test "$returncode" = 126 ; then
			log "ERROR: unable to call fat.format: cancel conversion" 1
			return 1
		fi
	fi

	# check for free space in sd
	if ! check_available_space $resource; then
		case $available_space_error in
			sdcard)
				log "WARNING: not enough space on sdcard to convert $resource" 1
				say "not-enough-space-sdcard"
				;;
			partition)
				say "not-enough-space-partition"
			;;
		esac
		log "$resource conversion cancelled" 1
		return 1
	else
		case $resource in
			system)
				# on small /system ROMS it takes less time, 2 minutes is a pessimistic prediction ;)
				say "time-estimated"
				say "2-minutes" ;;
			data)
				if test $dest_fs = 'rfs'; then
					# Converting to RFS takes a lot of time
					# measured to 60MB converted by minute
					test $resource_used -gt 45 && say "time-estimated"

					( test $resource_used -gt 45 && test $resource_used -le 60 && say "1-minute" ) || \
					( test $resource_used -gt 60 && test $resource_used -le 120 && say "2-minutes"  ) || \
					( test $resource_used -gt 120 && test $resource_used -le 180 && say "3-minutes" ) || \
					( test $resource_used -gt 180 && test $resource_used -le 240 && say "4-minutes" ) || \
					( test $resource_used -gt 240 && test $resource_used -le 300 && say "5-minutes" ) || \
					( test $resource_used -gt 300 && test $resource_used -le 600 && say "10-minutes" ) || \
					( test $resource_used -gt 600 && test $resource_used -le 900 && say "15-minutes" ) || \
					( test $resource_used -gt 900 && say "20-minutes+" )
				else
					# Converting to Ext4 takes less time
					# measured to 104MB converted by minute
					test $resource_used -gt 75 && say "time-estimated"

					( test $resource_used -gt 75 && test $resource_used -le 104 && say "1-minute" ) || \
					( test $resource_used -gt 104 && test $resource_used -le 208 && say "2-minutes"  ) || \
					( test $resource_used -gt 208 && test $resource_used -le 312 && say "3-minutes" ) || \
					( test $resource_used -gt 312 && test $resource_used -le 416 && say "4-minutes" ) || \
					( test $resource_used -gt 416 && test $resource_used -le 520 && say "5-minutes" ) || \
					( test $resource_used -gt 520 && test $resource_used -le 1040 && say "10-minutes" ) || \
					( test $resource_used -gt 1040 && test $resource_used -le 1560 && say "15-minutes" ) || \
					( test $resource_used -gt 1560 && say "20-minutes+" )
				fi ;;
		esac
	fi

	# in case we convert /system to RFS or we fallback to RFS due to missing
	# available space in Ext4, we need to keep a copy of some tools from here
	if test "$resource" = "system"; then
		copy_system_in_ram
		# /system has been unmounted
		remount_system=1
	fi

	log "backup $resource" 1
	say "backup"

	if ! mount_tmp $partition; then
		log "ERROR: unable to mount $partition" 1
		return 1
	fi

	log_time start
	# archive management
	if ! build_archive "$resource"_to_"$dest_fs"_backup; then
		log "ERROR: problem during $resource backup, the filesystem must be corrupt" 1
		log "This error comes after an RFS filesystem has been mounted without the standard -o check=no" 1
		if test $source_fs = rfs; then
			log "Attempting a mount with broken RFS options" 1
			# archive management
			mount -t rfs -o ro $partition /voodoo/tmp/mnt/
			if ! build_archive "$resource"_to_"$dest_fs"_backup_nocheckno; then
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
		set_fs_for $resource rfs
	else
		test $resource = system && umount /system && remount_system=1
		ext4_format
		set_fs_for $resource ext4
	fi

	log "restore $resource" 1
	say 'restore'

	if ! conversion_mount_and_restore; then
		# sometimes, despite the overhead calculation,
		# restore operation don't succeed in Ext4 because RFS and Ext4
		# are quite different in space usage in this case, let's
		# re-format it as RFS as Ext4 don't give us enough space
		set_system_as_rfs
		rfs_format $resource
		set_fs_for $resource rfs
		if ! conversion_mount_and_restore; then
			log "ERROR: sorry this one is unrecoverable, your /$resource may be incomplete"
			return 1
		fi

		log "WARNING: $resource has been converted back to RFS due to insufficient space in Ext4 mode" 1
	fi

	# deal with archive file
	if test "$debug_mode" = 1; then
		mv $archive $archive_saved
	else
		rm $archive
	fi

	umount_tmp

	# remount /system if needed
	test "$remount_system" = 1 && mount_ system

	# speak only for bigger partition conversions
	test $resource != cache && test $resource != dbdata && tell_conversion_happened=1

	# conversion is successful
	return 0
}



finalize_interrupted_rfs_conversion()
{
	# thanks to Mish for the original reboot idea

	min_size=500
	was_finalized=0

	asoundconf=/sdcard/Voodoo/asound.conf
	test -f $asoundconf && cp $asoundconf /etc/

	for resource in dbdata data system; do
		archive=/sdcard/voodoo_"$resource"_conversion.tar.lzo
		archive_ignored=/sdcard/voodoo_"$resource"_conversion_ignored.tar.lzo
		archive_failed=/sdcard/voodoo_"$resource"_conversion_failed_restore.tar.lzo

		# check if an archive is there and is more than min_size
		if test -f $archive; then

			# make sure /system is always unmounted
			umount /system 2>/dev/null

			# make sure the partition contains a valid filesystem or
			# format to RFS in case of problem with Ext4 modules
			if ! mount_ $resource; then
				rfs_format $resource
			fi

			# check if the resource partition is empty (or at contains less than $min_size of data)
			if test `du -s /$resource | cut -d/ -f1` -lt $min_size; then
				# we don't want watchdog rebooting on us here
				echo -n V > /dev/watchdog

				say 'restore'

				log "finalize /$resource conversion to RFS: restore backup"
				rm -rf /$resource/*
				umount /$resource

				log_time start
				# archive management
				if mount_tmp $partition && extract_archive "$resource"_rfs_conversion_workaround_restore; then
					log_time end
					log "/$resource backup restored, workaround successful" 1
					rm $archive
				else
					mv $archive $archive_failed
					log "/$resource restore error, unrecoverable error" 1
					log "attempt boot to recovery" 1
					/system/bin/reboot recovery
				fi
				umount_tmp

				test $resource = system && mount_ $resource
				was_finalized=1
			else
				log "found a /$resource conversion temporary archive but the partition looks already okay"
				log "/sdcard/voodoo_"$resource'_conversion.tar.lzo ignored'
				if test $debug_mode = 1; then
					mv $archive $archive_ignored
				else
					rm $archive
				fi
			fi
		fi
	done


	# if we rebooted here using the watchdog's facility, we are maybe in reality
	# in battery charging mode. As it is difficult to detect, lets just reboot
	if test $was_finalized = 1; then
		log "rebooting to the normal mode"
		log_suffix='-RFS-bug-workaround'
		manage_logs
		ensure_reboot
	fi
}


manage_logs()
{
	# Manage logs
	# clean up old logs on sdcard (more than 7 days)
	find /sdcard/Voodoo/logs/ -mtime +7 -delete

	# manage the voodoo_history log
	tail -n 1000 /sdcard/Voodoo/logs/voodoo_history_log.txt > /voodoo/logs/voodoo_history_log.txt
	echo >> /voodoo/logs/voodoo_history_log.txt
	cat /voodoo/logs/voodoo_history_log.txt /voodoo/logs/voodoo_log.txt > /sdcard/Voodoo/logs/voodoo_history_log.txt
	# save current voodoo_log in the sdcard
	cp /voodoo/logs/voodoo_log.txt $log_dir/

	# manage other logs
	cp $log_dir/* /voodoo/logs

	current_log_directory=`date '+%Y-%m-%d_%H-%M-%S'`$log_suffix
	mv $log_dir /sdcard/Voodoo/logs/$current_log_directory
}


readd_boot_animation()
{
	echo >> init.rc
	if test -f /data/local/bootanimation.zip || test -f /system/media/bootanimation.zip; then
		echo 'service bootanim /system/bin/bootanimation
			user graphics
			group graphics
			disabled
			oneshot' >> init.rc
	else
		echo 'service playlogos1 /system/bin/playlogos1
			user root
			oneshot' >> init.rc
	fi
}


get_cwm_fstab_mount_option_for()
{
	if test "$1" = "ext4"; then
		cwm_mount_options='journal=ordered,nodelalloc'
	else
		cwm_mount_options='check=no'
	fi
}
generate_cwm_fstab()
{
	for x in cache datadata data system; do
		get_partition_for $x
		get_fs_for $x
		get_cwm_fstab_mount_option_for $fs
		echo "$partition /$x $fs $cwm_mount_options" >> /voodoo/run/cwm.fstab
		echo "/$x $fs $partition" >> /voodoo/run/cwm_recovery.fstab
	done

	# internal sdcard/USB Storage
	echo "$sdcard_device /sdcard vfat rw,uid=1000,gid=1015,iocharset=iso8859-1,shortname=mixed,utf8" >> /voodoo/run/cwm.fstab
	echo "/sdcard vfat $sdcard_device" >> /voodoo/run/cwm_recovery.fstab

	# external sdcard/USB Storage
	echo "/dev/block/mmcblk1 /sd-ext vfat rw,uid=1000,gid=1015,iocharset=iso8859-1,shortname=mixed,utf8" >> /voodoo/run/cwm.fstab
	echo "/sd-ext vfat /dev/block/mmcblk1" >> /voodoo/run/cwm_recovery.fstab
}


letsgo()
{
	# free ram
	rm -rf /system_in_ram

	# deal with the boot animation
	mount_ data
	readd_boot_animation
	umount /data

	# mount Ext4 partitions
	test $cache_fs = ext4 && mount_ cache && > /voodoo/run/lagfix_enabled
	test $dbdata_fs = ext4 && mount_ dbdata && > /voodoo/run/lagfix_enabled
	test $data_fs = ext4 && mount_ data && > /voodoo/run/lagfix_enabled

	# for CWM 3.x
	generate_cwm_fstab

	test "$tell_conversion_happened" = 1 && say "lagfix-status-"$lagfix_enabled

	# remove the tarball in maximum compression mode
	rm -f compressed_voodoo_initramfs.tar.lzma

	verify_voodoo_install

	# if /data is an Ext4 filesystem, it means we need to activate
	# the fat.format wrapper protection
	test "$data_fs" = "ext4" && > /voodoo/run/lagfix_enabled
	
	# run additionnal extensions scripts
	# actually they are sourced so they can use the init functions,
	# resources and variables
	
	# run extensions only if the model is detected
	if test -n "$model"; then
		if test "`find /voodoo/extensions/ -name '*.sh'`" != "" ; then
			for x in /voodoo/extensions/*.sh; do
				log "running extension: `echo $x | cut -d'/' -f 4`"
				. "$x"
			done
		fi
	fi

	log "running init !"

	#readd_boot_animation
	manage_logs

	# remove voices from memory
	rm -r /voodoo/voices

	# boot successful, no need to keep asound.conf on the sdcard
	rm /sdcard/Voodoo/asound.conf

	# remove CWM setup files
	rm -rf /cwm

	# set the etc to Android standards
	rm /etc
	# on Froyo initramfs, there is no etc to /etc/system symlink anymore

	if test "$system_fs" = "rfs"; then
		umount /system
	fi
	
	# exit this main script (the runner will execute samsung_init )
	exit
}

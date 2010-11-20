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
				mount -t rfs -o rw,check=no $system_partition /system
			fi
		;;
	esac
}


mount_tmp()
{
	# used during conversions and detection
	mount -t ext4 $1 -o barrier=0 /voodoo/tmp/mnt/ || mount -t rfs -o check=no $1 /voodoo/tmp/mnt/
}

log_time()
{
	test "$1" = "start" && start=`date '+%s'` && return
	if test "$1" = "end"; then
		end=`date '+%s'`
		log 'time spent: '$(( end - start))'s' 1
	fi
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
		if test "$model" = "fascinate"; then
			data_partition="/dev/block/mmcblk0p1"
		else
		# for every other model
			data_partition="/dev/block/mmcblk0p2"
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
			umount /voodoo/tmp/mnt
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
	test "$2" = 1 && indent="    " || test "$2" = 2 && indent="        "
	echo "`date '+%Y-%m-%d %H:%M:%S'` $indent $1" >> /voodoo/logs/voodoo.log
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
	test -f /cache/update.zip && test -f /cache/recovery/command || \
		test -d /cwm
}


enough_space_to_convert()
{
	resource=$1
	log "check space for $resource:" 1
	
	mount_ $resource
	
	# make sure df is there
	df || return 1

	# read free space on internal SD
	target_free=$((`df $sdcard | cut -d' ' -f 6 | cut -d K -f 1` / 1024 ))

	# read space used by data we need to save
	space_needed=$((`df /$resource | cut -d' ' -f 4 | cut -d K -f 1` / 1024 ))

	log "free space:   $target_free MB" 2
	log "space needed: $space_needed MB" 2

	# more than 100MB on /data, talk to the user
	test $space_needed -gt 100 && say "wait"

	# umount the resource
	test "$resource" != "system" && umount /$resource

	# ask for 10% more free space for security reasons
	test $target_free -ge $(( $space_needed + $space_needed / 10))
}


rfs_format()
{
	log "format $1 as RFS" 1
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
	echo >> /voodoo/logs/rfs_formatter.log

	# let's restore the original .rc files
	rm *.rc
	mv /voodoo/tmp/*.rc ./
}


copy_system_in_ram()
{
	if ! test -d /system_in_ram; then
		# save /system stuff
		log "make a limited copy of /system in ram" 1
		mkdir /system_in_ram
		cp -rp /system/lib /system_in_ram
		cp -rp /system/bin /system_in_ram
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
	
	if test $fs = $dest_fs; then
		log "no need to convert $resource"
		return
	fi
	log "convert $resource ($partition) from $fs to $dest_fs"

	if ! enough_space_to_convert $resource; then
		log "ERROR: not enough space to convert $resource" 1
		say "cancel-no-space"
		return 1
	fi
	
	if test "$dest_fs" = "rfs" && test "$resource" = "system"; then
		copy_system_in_ram
	fi

	log "backup $resource" 1
	say "step1"

	log_time start
	mount_tmp $partition
	if ! tar cvf $sdcard/voodoo_conversion.tar /voodoo/tmp/mnt/; then
		log "ERROR: problem during $resource backup" 1
		return 1
	fi
	umount /voodoo/tmp/mnt/
	log_time end
	
	log "format $partition" 1
	if test "$dest_fs" = "rfs"; then
		rfs_format $resource
	else
		umount /system
		if test $resource = "data"; then
			journal_size=12
			features='sparse_super,'
		else
			journal_size=4
			features=''
		fi
		echo "wipe clean RFS partition"
		dd if=/dev/zero of=$partition bs=1024 count=$(( 5 * 1024 ))
		mkfs.ext4 -F -O "$features"^resize_inode -J size=$journal_size -T default $partition
		# force check the filesystem after 100 mounts or 100 days
		tune2fs -c 100 -i 100d -m 0 $partition
	fi

	log "restore $resource" 1
	say "step2"

	log_time start
	mount_tmp $partition
	if ! tar xvf $sdcard/voodoo_conversion.tar; then
		log "ERROR: problem during $resource restore" 1
		return 1
	fi
	log_time end
	rm $sdcard/voodoo_conversion.tar
	
	umount /voodoo/tmp/mnt/

	# remount /system
	test "$resource" = "system" && system_fs=$dest_fs
	mount_ system

	# if we get out of the conversion process with an Ext4 filesystem,
	# it means we need to activate the fat.format wrapper protection
	test "$dest_fs" = "ext4" && > /voodoo/run/ext4_enabled
}


letsgo()
{
	rm -rf /system_in_ram
	
	# remove the tarball in maximum compression mode
	rm -f compressed_voodoo_ramdisk.tar.lzma
	
	# dump logs to the sdcard
	# create the Voodoo dir in sdcard if not here already
	test -f $sdcard/Voodoo && rm $sdcard/Voodoo
	mkdir $sdcard/Voodoo 2>/dev/null

	verify_voodoo_install
	
	# run additionnal extensions scripts
	# actually they are sourced so they can use the init functions,
	# resources and variables
	
	for x in /voodoo/extensions/*.sh; do
		log "running extension: `echo $x | cut -d'/' -f 4`"
		. "$x"
	done

	log "running init !"

	# Manage logs

	# copy some logs in it to help debugging
	mkdir $sdcard/Voodoo/logs 2>/dev/null

	# clean up old logs (more than 7 days)
	find $sdcard/Voodoo/logs/ -mtime +7 -delete

	# manage the voodoo log
	tail -n 1000 $sdcard/Voodoo/logs/voodoo_log.txt > /voodoo/logs/voodoo_log.txt
	echo >> /voodoo/logs/voodoo_log.txt
	cat /voodoo/logs/voodoo_log.txt /voodoo/logs/voodoo.log > $sdcard/Voodoo/logs/voodoo_log.txt
	rm /voodoo/logs/voodoo_log.txt

	init_log_filename=init-"`date '+%Y-%m-%d_%H-%M-%S'`".txt
	cp /voodoo/logs/init.log $sdcard/Voodoo/logs/$init_log_filename
	rm $sdcard/init.log
	
	# remove voices from memory
	rm -r /voodoo/voices

	# set the etc to Android standards
	rm /etc
	# on Froyo ramdisk, there is no etc to /etc/system symlink anymore

	if test "$system_fs" = "rfs"; then
		umount /system
	fi
	
	# exit this main script (the runner will execute samsung_init )
	exit
}


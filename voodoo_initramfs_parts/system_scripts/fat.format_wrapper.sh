#!/system/bin/sh
# This is a part of Voodoo lagfix
# fat.format wrapper
# acts 100% normally if not run by samsung init in Voodoo lagfix in Ext4 mode
# partition is $7 when called by init_samsung

export PATH=/system/bin:/bin:/sbin
. /voodoo/configs/shared 2>/dev/null

logname="fat.format_wrapper_log.txt"

# back 2 levels
parent_pid=`cut -d" " -f4 /proc/self/stat`
parent_pid=`cut -d" " -f4 /proc/$parent_pid/stat`
parent_name=`cat /proc/$parent_pid/cmdline`

case $parent_name in
	/init_samsung)
		if ls /voodoo/run/lagfix_enabled > /dev/null 2>&1 ; then
			echo "Ext4 activated and fat.format called by init_samsung. nothing done" \
				>> /voodoo/logs/$logname
			echo "command was $0 $*" >> /voodoo/logs/$logname
			exit 0
		fi
	;;
esac

fat.format.real $*

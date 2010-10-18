#!/system/bin/sh
# This is a part of Voodoo lagfix
# fat.format wrapper
# acts 100% normally if not run by samsung init in Voodoo lagfix in Ext4 mode
# partition is $7 when called by init_samsung

# activate debugging logging
exec >> /voodoo/logs/fat.format_wrapper.log 2>&1
export PATH=/system/bin:/voodoo/root/bin


# back 2 levels
parent_pid=`cut -d" " -f4 /proc/self/stat`
parent_pid=`cut -d" " -f4 /proc/$parent_pid/stat`
parent_name=`cat /proc/$parent_pid/cmdline`

case $parent_name in
	/init_samsung)
		if ls /voodoo/run/voodoo_data_mounted; then
			echo "Ext4 activated and fat.format called by init_samsung. nothing done"
			exit 0
		fi
	;;
esac

fat.format.real $*

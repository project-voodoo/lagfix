#!/bin/sh
# the strange fat.format wants some specific setup around to run.
# using init_samsung to provide it and then... killing it without mercy
PATH=/bin:/sbin:/system/bin
set -x
exec >> /voodoo/logs/rfs_formatter.log 2>&1

# load partitions references
. /voodoo/configs/partitions

resource_to_format="`cat /voodoo/run/rfs_format_what`"
echo "format $resource_to_format:\n"

case $resource_to_format in
	cache)
		fat.format -v -S 4096 -s 1 -F 16 $cache_partition
	;;
	dbdata)
		fat.format -v -S 4096 -s 1 -F 16 $dbdata_partition
	;;
	data)
		fat.format -v -S 4096 -s 4 -F 32 $data_partition
	;;
	system)
		fat.format -v -S 4096 -s 1 -F 32 $system_partition
	;;
esac


# kill/quit :D
killall -9 init_samsung

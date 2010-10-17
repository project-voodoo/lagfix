#!/system/bin/sh

if `ls /tmp/ext4_mounted > /dev/null 2>&1`; then
	return 0

fat.format.real $?

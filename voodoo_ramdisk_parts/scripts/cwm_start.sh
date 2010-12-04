#!/bin/sh
# mostly replicate updater-script behavior from CWM as update.zip
set -x
export PATH=$PATH:/bin

exec > /voodoo/logs/cwm_start_log.txt 2>&1

# froyo make /sdcard a symlink to /mnt/sdcard, which confuses CWM
rm /sdcard
mkdir /sdcard

ln -s busybox /sbin/[
ln -s busybox /sbin/[[
ln -s recovery /sbin/amend
ln -s busybox /sbin/ash
ln -s busybox /sbin/awk
ln -s busybox /sbin/basename
ln -s busybox /sbin/bbconfig
ln -s busybox /sbin/bunzip2
#ln -s recovery /sbin/busybox
ln -s busybox /sbin/bzcat
ln -s busybox /sbin/bzip2
ln -s busybox /sbin/cal
ln -s busybox /sbin/cat
ln -s busybox /sbin/catv
ln -s busybox /sbin/chgrp
ln -s busybox /sbin/chmod
ln -s busybox /sbin/chown
ln -s busybox /sbin/chroot
ln -s busybox /sbin/cksum
ln -s busybox /sbin/clear
ln -s busybox /sbin/cmp
ln -s busybox /sbin/cp
ln -s busybox /sbin/cpio
ln -s busybox /sbin/cut
ln -s busybox /sbin/date
ln -s busybox /sbin/dc
ln -s busybox /sbin/dd
ln -s busybox /sbin/depmod
ln -s busybox /sbin/devmem
ln -s busybox /sbin/df
ln -s busybox /sbin/diff
ln -s busybox /sbin/dirname
ln -s busybox /sbin/dmesg
ln -s busybox /sbin/dos2unix
ln -s busybox /sbin/du
ln -s recovery /sbin/dump_image
ln -s busybox /sbin/echo
ln -s busybox /sbin/egrep
ln -s busybox /sbin/env
ln -s recovery /sbin/erase_image
ln -s busybox /sbin/expr
ln -s busybox /sbin/false
ln -s busybox /sbin/fdisk
ln -s busybox /sbin/fgrep
ln -s busybox /sbin/find
ln -s recovery /sbin/flash_image
ln -s busybox /sbin/fold
ln -s busybox /sbin/free
ln -s busybox /sbin/freeramdisk
ln -s busybox /sbin/fuser
ln -s busybox /sbin/getopt
ln -s busybox /sbin/grep
ln -s busybox /sbin/gunzip
ln -s busybox /sbin/gzip
ln -s busybox /sbin/head
ln -s busybox /sbin/hexdump
ln -s busybox /sbin/id
ln -s busybox /sbin/insmod
ln -s busybox /sbin/install
ln -s busybox /sbin/kill
ln -s busybox /sbin/killall
ln -s busybox /sbin/killall5
ln -s busybox /sbin/length
ln -s busybox /sbin/less
ln -s busybox /sbin/ln
ln -s busybox /sbin/losetup
ln -s busybox /sbin/ls
ln -s busybox /sbin/lsmod
ln -s busybox /sbin/lspci
ln -s busybox /sbin/lsusb
ln -s busybox /sbin/lzop
ln -s busybox /sbin/lzopcat
ln -s busybox /sbin/md5sum
ln -s busybox /sbin/mkdir
ln -s busybox /sbin/mke2fs
ln -s busybox /sbin/mkfifo
ln -s busybox /sbin/mkfs.ext2
ln -s busybox /sbin/mknod
ln -s busybox /sbin/mkswap
ln -s busybox /sbin/mktemp
ln -s recovery /sbin/mkyaffs2image
ln -s busybox /sbin/modprobe
ln -s busybox /sbin/more
#ln -s busybox /sbin/mount
ln -s busybox /sbin/mountpoint
ln -s busybox /sbin/mv
ln -s recovery /sbin/nandroid
ln -s busybox /sbin/nice
ln -s busybox /sbin/nohup
ln -s busybox /sbin/od
ln -s busybox /sbin/patch
ln -s busybox /sbin/pgrep
ln -s busybox /sbin/pidof
ln -s busybox /sbin/pkill
ln -s busybox /sbin/printenv
ln -s busybox /sbin/printf
ln -s busybox /sbin/ps
ln -s busybox /sbin/pwd
ln -s busybox /sbin/rdev
ln -s busybox /sbin/readlink
ln -s busybox /sbin/realpath
ln -s recovery /sbin/reboot
ln -s busybox /sbin/renice
ln -s busybox /sbin/reset
ln -s busybox /sbin/rm
ln -s busybox /sbin/rmdir
ln -s busybox /sbin/rmmod
ln -s busybox /sbin/run-parts
ln -s busybox /sbin/sed
ln -s busybox /sbin/seq
ln -s busybox /sbin/setsid
ln -s busybox /sbin/sh
ln -s busybox /sbin/sha1sum
ln -s busybox /sbin/sha256sum
ln -s busybox /sbin/sha512sum
ln -s busybox /sbin/sleep
ln -s busybox /sbin/sort
ln -s busybox /sbin/split
ln -s busybox /sbin/stat
ln -s busybox /sbin/strings
ln -s busybox /sbin/stty
ln -s busybox /sbin/swapoff
ln -s busybox /sbin/swapon
ln -s busybox /sbin/sync
ln -s busybox /sbin/sysctl
ln -s busybox /sbin/tac
ln -s busybox /sbin/tail
ln -s busybox /sbin/tar
ln -s busybox /sbin/tee
ln -s busybox /sbin/test
ln -s busybox /sbin/time
ln -s busybox /sbin/top
ln -s busybox /sbin/touch
ln -s busybox /sbin/tr
ln -s busybox /sbin/true
ln -s busybox /sbin/tty
ln -s busybox /sbin/umount
ln -s busybox /sbin/uname
ln -s busybox /sbin/uniq
ln -s busybox /sbin/unix2dos
ln -s busybox /sbin/unlzop
ln -s recovery /sbin/unyaffs
ln -s busybox /sbin/unzip
ln -s busybox /sbin/uptime
ln -s busybox /sbin/usleep
ln -s busybox /sbin/uudecode
ln -s busybox /sbin/uuencode
ln -s busybox /sbin/watch
ln -s busybox /sbin/wc
ln -s busybox /sbin/which
ln -s busybox /sbin/whoami
ln -s busybox /sbin/xargs
ln -s busybox /sbin/yes
ln -s busybox /sbin/zcat


# also shorter
echo '#!/sbin/sh
set -x
exec >> /voodoo/logs/cwm_postrecoveryboot_log.txt 2>&1
rm /etc
mkdir -p /etc
mkdir -p /datadata
chmod 4777 /sbin/su
umount /efs
umount /dbdata
umount /data

# succeed to mount the sdcard by default even with broken fstab
mount -t vfat -o rw,nosuid,nodev,noexec,uid=1000,gid=1015,fmask=0002,dmask=0002,allow_utime=0020,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro "`cat /voodoo/run/sdcard_device`" /sdcard
' > /sbin/postrecoveryboot.sh


# run the actual recovery
/sbin/recovery &

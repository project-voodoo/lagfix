#!/bin/sh
#
# By François SIMOND for project-voodoo.org
# License GPL v3
#
# generate Voodoo ramdisk
# use a standard ramdisk directory as input, and make it Voodoo!
# recommanded to wipe the destination directory first
#
# usage: generate_voodoo_ramdisk.sh stock_ramdisk voodoo_ramdisk voodoo_ramdisk_parts
#

if ! test -d "$3" || ! test -n "$2" || ! test -d "$1" ; then
	echo "please specify 3 valid directories names"
	exit 1
fi

my_pwd=`pwd`

# create the destination directory
mkdir $2 2>/dev/null

# copy the ramdisk source to the voodoo ramdisk directory
cp -ax $1/* $2/
cd $2

mv init init_samsung

# copy ramdisk stuff
mkdir voodoo 2>/dev/null
cp -ax $my_pwd/$3/* voodoo/


# make sure su binary (Superuser.apk) is fully suid
chmod 06755 voodoo/root/bin/su


# empty directories, probably not in gits
mkdir dev 2>/dev/null
mkdir proc 2>/dev/null
mkdir sys 2>/dev/null
mkdir system 2>/dev/null

mkdir dev/block
mkdir dev/snd
mkdir voodoo/tmp
mkdir voodoo/root/usr

# symlink to voodoo stuff
ln -s voodoo/root/bin .
ln -s voodoo/root/usr .
ln -s ../bin/busybox sbin/hdparm 
ln -s ../bin/busybox sbin/insmod


# create the main init symlink
ln -s voodoo/scripts/init_logger.sh init
#ln -s init_samsung init


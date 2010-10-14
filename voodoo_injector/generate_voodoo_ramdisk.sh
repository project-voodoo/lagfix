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

cp -ax $1/* $2/
cd $2

mv init init_samsung

# make sure su binary is fully suid
chmod 06755 sbin/su

# copy ramdisk stuff

mkdir voodoo 2>/dev/null
cp -axvi $my_pwd/$3/*  voodoo

#ln -s voodoo/

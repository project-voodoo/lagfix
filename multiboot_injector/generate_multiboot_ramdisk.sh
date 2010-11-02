#!/bin/sh
#
# By François SIMOND for project-voodoo.org
# License GPL v3
#
# generate 4 Voodoo ramdisks
# use a standard ramdisk directory as input, and make it Voodoo!
# recommanded to wipe the destination directory first
#
# usage: generate_multiboot_ramdisk.sh stock_ramdisk multiboot_ramdisk
#

make_cpio() {
	echo "creating a cpio for $1"
	cd $1 || exit "error during stage cpio file creation"
	find | fakeroot cpio -H newc -o > ../$1.cpio
	ls -lh ../$1.cpio
	cd - >/dev/null
	echo 
}


if ! test -d "$1" || ! test -n "$2"; then
	echo "please specify 2 valid directories names"
	exit 1
fi

source=$1
dest=$2
my_pwd=`pwd`

# create the destination directory
mkdir $dest 2>/dev/null

# copy the ramdisk source to the voodoo ramdisk directory
cp -ax $source $dest/uncompressed
cd $dest/uncompressed

mv init init_samsung


# empty directories, probably not in gits
mkdir dev 2>/dev/null
mkdir proc 2>/dev/null
mkdir sys 2>/dev/null
mkdir system 2>/dev/null
mkdir dev/block

mkdir multiboot_external_sd/

# create the main init symlink

# extract stage1 busybox
tar xf ../../../lagfix/stages_builder/stages/stage1.tar


# clean git stuff
find -name '.git*' -exec rm {} \;

# write the autodetect init script

echo '#!/bin/sh
# Voodoo multiboot from external script
# logging
exec > multiboot_init.log 2>&1

log()
{
	echo "Voodoo multiboot: $*"
}

export PATH=/bin:/sbin

# make the useful device
mknod /dev/block/mmcblk1 b 179 8

if mount -t vfat -o utf8,uid=1000,gid=1015 /dev/block/mmcblk1 /multiboot_external_sd; then
		if tar xf /multiboot_external_sd/multiboot_ramdisk.tar; then
			test -x /pre-init.sh && /pre-init.sh
			exec /init
		else
			log "no tar file"
			umount /multiboot_external_sd
		fi
else
	log "unable to mount the external sd"
fi

log "running samsung init"
exec /init_samsung' > init

chmod 755 init


cd ..
# do the uncompressed one
# extract stages directly
echo "Build the uncompressed ramdisk"

make_cpio uncompressed

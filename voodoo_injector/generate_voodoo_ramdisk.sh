#!/bin/sh
#
# By François SIMOND for project-voodoo.org
# License GPL v3
#
# generate 4 Voodoo ramdisks
# use a standard ramdisk directory as input, and make it Voodoo!
# recommanded to wipe the destination directory first
#
# usage: generate_voodoo_ramdisk.sh stock_ramdisk voodoo_ramdisks voodoo_ramdisk_parts stages_source build_only_uncompressed
#

make_cpio()
{
	echo "creating a cpio for $1"
	cd $1 || exit "error during stage cpio file creation"
	find | fakeroot cpio -H newc -o > ../$1.cpio
	ls -lh ../$1.cpio
	cd - >/dev/null
	echo 
}


optimize_cwm_directory()
{
	test -d cwm || return
	rm -rf cwm/META_INF
	rm -f cwm/res/sh
	rm -f cwm/sbin/fformat
	rm -f cwm/killrecovery.sh

	rm -f cwm/sbin/e2fsck
	ln -s /usr/sbin/e2fsck cwm/sbin/e2fsck

	rm -f cwm/sbin/tune2fs
	ln -s /usr/sbin/tune2fs cwm/sbin/tune2fs
}


activate_recovery_wrapper()
{
	sed s/"service recovery .*bin\/recovery"/"service recovery \/voodoo\/scripts\/recovery_wrapper.sh"/ recovery.rc > /tmp/recovery.rc
	#cp /tmp/recovery.rc .
	sed s/"service console \/system\/bin\/sh"/''/ /tmp/recovery.rc | \
		sed s/".*console$"/""/ > recovery.rc
}


add_run_parts()
{
	rc_file=$1
	echo "\nservice run-parts /voodoo/scripts/run-parts.sh /system/etc/init.d" >> $rc_file
	echo "  oneshot \n" >> $rc_file

	echo "start run-parts" >> $rc_file
}


change_memory_management_settings()
{
	cat init.rc | \
	sed s/"FOREGROUND_APP_MEM.*"/"FOREGROUND_APP_MEM 2560"/ | \
	sed s/"VISIBLE_APP_MEM.*"/"VISIBLE_APP_MEM 4096"/ | \
	sed s/"SECONDARY_SERVER_MEM.*"/"SECONDARY_SERVER_MEM 6144"/ | \
	sed s/"BACKUP_APP_MEM.*"/"BACKUP_APP_MEM 6144"/ | \
	sed s/"HOME_APP_MEM.*"/"HOME_APP_MEM 6144"/ | \
	sed s/"HIDDEN_APP_MEM.*"/"HIDDEN_APP_MEM 12288"/ | \
	sed s/"CONTENT_PROVIDER_MEM.*"/"CONTENT_PROVIDER_MEM 13312"/ | \
	sed s/"EMPTY_APP_MEM.*"/"EMPTY_APP_MEM 16384"/ > /tmp/init.rc

	cat /tmp/init.rc | \
	sed s/"lowmemorykiller\/parameters\/minfree 2560,4096,6144,10240,11264,12288"/"lowmemorykiller\/parameters\/minfree 2560,4096,6144,12288,13312,16384"/ > init.rc
}


if ! test -d "$3" || ! test -n "$2" || ! test -d "$1" ; then
	echo "please specify 3 valid directories names"
	exit 1
fi

source=$1
dest=$2
voodoo_ramdisk_parts=$3
# FIXME: fix this messy stage source stuff
stages_source=$4

my_pwd=`pwd`


# create the destination directory
mkdir $dest 2>/dev/null


# test if stage2 and at least stage3-sound exist
# FIXME: paths madness
cd lagfix/stages_builder/stages
if ! test -f stage2* || ! test -f stage3-sound*; then
	echo "\n\n # Error, please build the Voodoo lagfix stages first\n\n"
	exit 1
fi
cd - > /dev/null


# copy the ramdisk source to the voodoo ramdisk directory
cp -ax $source $dest/uncompressed
cd $dest/uncompressed

mv init init_samsung

# change recovery.rc to call a wrapper instead of the real recovery binary
activate_recovery_wrapper

# change memory thresholds too Voodoo optimized ones
change_memory_management_settings

# run-parts support
add_run_parts init.rc
add_run_parts recovery.rc

# optimize CWM directory if it's there
optimize_cwm_directory

# copy ramdisk stuff
mkdir voodoo 2>/dev/null
cp -ax $my_pwd/$voodoo_ramdisk_parts/* voodoo/


# empty directories, probably not in gits
mkdir dev 2>/dev/null
mkdir proc 2>/dev/null
mkdir sys 2>/dev/null
mkdir system 2>/dev/null
mkdir dev/block
mkdir dev/snd
mkdir voodoo/tmp
mkdir voodoo/tmp/sdcard
mkdir voodoo/tmp/mnt
mkdir voodoo/root/usr


# symlink to voodoo stuff
ln -s voodoo/root/bin .
ln -s voodoo/root/usr .
# etc symlink will be used only during extraction of stages
# after that it needs to be removed
rm -f etc
ln -s voodoo/root/etc .
ln -s ../bin/busybox bin/insmod


# create the main init symlink
ln -s voodoo/scripts/init_runner.sh init
#ln -s init_samsung init


# extract stage1 busybox
tar xf ../../../lagfix/stages_builder/stages/stage1.tar


# clean git stuff
find -name '.git*' -exec rm {} \;


# generate signatures for the stage
# because you want to be able to load them from the sdcard
for x in ../../../lagfix/stages_builder/stages/*.lzma; do
	sha1sum "$x" | cut -d' ' -f1 >> voodoo/signatures/`basename "$x" .tar.lzma`	
done


# copy the uncompressed ramdisk to the compressed before decompressing
# stage images in it
cd ..
cp -a uncompressed compressed


# do the uncompressed one
# extract stages directly
echo "Build the uncompressed ramdisk"
cd uncompressed
for x in ../../../lagfix/stages_builder/stages/*.lzma; do
	lzcat "$x" | tar x
	> voodoo/run/`basename "$x" .tar.lzma`_loaded
done

# remove the etc symlink wich will causes problems when we boot
# directly on samsung_init
rm etc
cd ..

make_cpio uncompressed

if ! test -n "$5"; then
	echo "Building only uncompressed ramdisk"
	exit
fi


# do the smallest one. this one is wickely compressed!
echo "Build the compressed-smallest ramdisk"
cp -a uncompressed compressed-smallest
cd compressed-smallest
rm voodoo/run/*
rm bin
rm init
echo '#!/bin/sh
export PATH=/bin

lzcat compressed_voodoo_ramdisk.tar.lzma | tar x
exec /voodoo/scripts/init_runner.sh' > init
chmod 755 init
mv voodoo/root/bin .

rm -r voodoo/voices
stage0_list="lib/ sbin/ voodoo/ res/ modules/ *.rc init_samsung default.prop"
find $stage0_list 2>/dev/null | xargs tar c | lzma -9 > compressed_voodoo_ramdisk.tar.lzma
rm -r $stage0_list
cd ..

make_cpio compressed-smallest


# do the compressed one
echo "Build the compressed ramdisk"
cp -a ../../lagfix/stages_builder/stages/*.lzma compressed/voodoo/
cd compressed
rm -r voodoo/voices
# important: remove the etc symlink
rm etc
cd ..

make_cpio compressed


echo "Build the compressed-stage2-only"
cp -a compressed compressed-stage2-only
rm compressed-stage2-only/voodoo/stage3*

make_cpio compressed-stage2-only


echo

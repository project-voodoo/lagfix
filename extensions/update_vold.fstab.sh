# Voodoo lagfix extension

name='updated vold configuration file'
dest='/system/etc/vold.fstab'

extension_update_old_froyo_voldfstab()
{
	# downgrade vold.fstab conditionnaly
	for z in /voodoo/extensions/vold_fstabs/*; do
		if cmp /system/etc/vold.fstab "$z"/new_froyo_vold.fstab; then
			cp "$z"/old_froyo_vold.fstab $dest
			extension_post_install_voldfstab
		fi
	done
}

extension_update_new_froyo_voldfstab()
{
	# upgrade vold.fstab conditionnaly
	for z in /voodoo/extensions/vold_fstabs/*; do
		if cmp /system/etc/vold.fstab "$z"/old_froyo_vold.fstab; then
			cp "$z"/new_froyo_vold.fstab $dest
			extension_post_install_voldfstab
		fi
	done
}

extension_post_install_voldfstab()
{
	# make sure it's owned by root
	chown 0.0 $dest
	# sets the permissions
	chmod 644 $dest
	log "$name now installed"
}

install_condition()
{
	test -f "/system/etc/vold.fstab"
}


if install_condition; then

	# test for old Samsung 2.2 kernels
	if test -f /sys/devices/platform/s3c-usbgadget/gadget/lun2/file; then
		extension_update_old_froyo_voldfstab
	elif test -f /sys/devices/platform/s3c-usbgadget/gadget/lun0/file; then
		extension_update_new_froyo_voldfstab
	fi
else
	echo "not installing $name"
fi

# Voodoo lagfix extension

name='secure su binary for Superuser apk'
source='/voodoo/extensions/su/su-2.3.6.1-ef'
dest='/system/xbin/su'

extension_install_su()
{
	cp $source $dest
	# make sure it's owned by root
	chown 0.0 $dest
	# sets the suid permission
	chmod 06755 $dest
	log "$name now installed"
}

install_condition()
{
	test -d "/system/xbin"
}


if install_condition; then
	# test if the su binary already exist in xbin
	if test -u $dest ; then
		# okay, the su binary exist and is already suid
		if test $source -nt $dest; then

			# but it's older than ours ! let's updated it
			extension_install_su
		else
			# ours is the same or older, don't touch it
			log "$name already installed"
		fi
	else
		# not here or not setup properly, let's install su
		extension_install_su
	fi
else
	log "$name cannot be installed"
fi

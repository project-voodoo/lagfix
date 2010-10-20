# Voodoo lagfix extension

su_dest="/system/xbin/su"


extension_install_su() {
	cat /voodoo/root/sbin/su > $su_dest
	# make sure it's owned by root
	chown root $su_dest
	# sets the suid permission
	chmod 06755 $su_dest
	log "secure su binary installed"
}

# test if the su binary already exist in xbin
if test -u $su_dest ; then

	# okay, the su binary exist and is already suid
	if test /voodoo/root/sbin/su -nt $su_dest; then

		# but it's older than ours ! let's updated it
		extension_install_su
	else
		# ours is the same or older, don't touch it
		log "secure su binary already installed"
	fi	
else
	# not here or not setup properly, let's install su
	extension_install_su
fi

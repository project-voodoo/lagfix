# Voodoo lagfix extension

su_dest="/system/xbin/su"

# test if the su binary already exist in xbin

extension_install_su() {
	cat /voodoo/root/sbin/su > $su_dest
	chown root.shell $su_dest
	chmod 06755 $su_dest
	# make sure it's owned by root
	log "secure su binary installed"
}

if test -u $su_dest ; then
	if test /voodoo/root/sbin/su -nt $su_dest; then
		extension_install_su
	else
		log "secure su binary already installed"
	fi	
else
	extension_install_su
fi
	


# Voodoo lagfix extension

name='BackLightNotification improved liblights'
source='/voodoo/extensions/bln/lights.PACKAGENAME.so'

if test -f "/system/lib/hw/lights.default.so"; then
	# Eclair
	filename='lights.default.so'
else
	# Froyo
	filename='lights.s5pc110.so'
fi

dest="/system/lib/hw/$filename"
backup="/system/lib/hw/$filename-backup-"`date '+%Y-%m-%d_%H-%M-%S'`

install_condition()
{
	test -d "/system/lib/hw/" && test -d "/sys/class/misc/backlightnotification"
}

extension_install_bln()
{
	# be nice, make a backup please
	mv $dest $backup
	cp $source $dest
	# make sure it's owned by root
	# set default permissions
	chown 0.0 $dest && chmod 644 $dest && log "$name now installed" || \
		log "problem during $name installation"

}

# see if our liblights is not installed

if install_condition; then
	if ! cmp $source $dest; then
		# we need our liblights
		extension_install_bln
	else
		# ours is the same don't touch it
		log "$name already installed"
	fi
else
	log "$name cannot be installed or is not supported"
fi

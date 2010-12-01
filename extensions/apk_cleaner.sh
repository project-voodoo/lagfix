# Voodoo lagfix extension

zip='/voodoo/extensions/apk_cleaner/zip'
zipalign='/voodoo/extensions/apk_cleaner/zipalign'

# ensure the zip binary is available
if test -x $zip; then

	# clean apk's inside!
	apk='/system/app/TouchWiz30Launcher.apk'
	apk_tmp='/voodoo/tmp/TouchWiz30Launcher.apk'
	if test -f $apk; then
		if test `du -s $apk | cut -d/ -f1` -gt 1600 ; then
			cp $apk $apk_tmp
			$zip -d $apk_tmp res/*1024x600*
			$zipalign -v -f 4 $apk_tmp $apk
			log "TouchWiz 3.0 Launcher cleaned up: apk now optimized"
		else
			log "TouchWiz 3.0 Launcher already optimized"
		fi
	fi

else
	log "ERROR: apk_cleaner cannot do its job. zip binary is missing"
	log "please contact your Voodoo lagfix kernel vendor to notify this error"
fi

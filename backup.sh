#!/bin/sh

# --------------------------------------------------
# set variables:
# --------------------------------------------------
mountdirectory=/Volumes/blomma-1
backupdirectory=$mountdirectory/backup
directoryname=ibook/"Week_"`date +%V`
fullbackuplabel="Full Backup of "`hostname`" on "`date '+%B %e, %Y'`
fullbackupname=`date +%Y-%m-%d`"_full.tar.gz"
fullbackuplogname=`date +%Y-%m-%d`"_full.log"
incrementalbackuplabel="Incremental Backup of "`hostname`" on "`date '+%B %e, %Y'`
incrementalbackupname=`date +%Y-%m-%d`"_incremental"`date +%H%M`".tar.gz"
incrementalbackuplogname=`date +%Y-%m-%d`"_incremental"`date +%H%M`".log"
filesfrom=/Users/blomma/Projects/sh/Backup/whattobackup
excludefrom=/Users/blomma/Projects/sh/Backup/whatnottobackup
tar=/usr/bin/tar
MSMTP=/Users/blomma/Opt/bin/msmtp

# Create tempfile
tempfoo=`basename $0`
tempfile=`mktemp -q /tmp/${tempfoo}.XXXXXX`
if [ $? -ne 0 ]; then
	echo "$0: Can't create temp file, exiting..."
	exit 1
fi

# Mail
mailsubject=""
mailaddress="log@blomma.fastmail.fm"

# --------------------------------------------------
# functions:
# --------------------------------------------------
logmessage()
{
	echo $1 | tee -a $tempfile
}

fullbackup()
{
	mailsubject=$fullbackuplabel

	# create backup directory
	if test ! -e $backupdirectory/$directoryname; then

		logmessage "Creating $backupdirectory/$directoryname directory"
		mkdir -p $backupdirectory/$directoryname

	fi

	# keep track of creation date of full backup (used with incremental backups)
	logmessage "Updating $backupdirectory/$directoryname/lastfullbackupdate"
	date > $backupdirectory/$directoryname/lastfullbackupdate
	
	# create backup
	logmessage "Running tar..."
	starttime="STARTTIME: "`date +%H:%M:%S`
	logmessage "$starttime"
	$tar --create  --label "$fullbackuplabel" --files-from $filesfrom --exclude-from $excludefrom --ignore-failed-read --absolute-names --verbose --gzip --file $backupdirectory/$directoryname/$fullbackupname > $backupdirectory/$directoryname/$fullbackuplogname 2>&1
	logmessage "$stoptime"
	stoptime="STOPTIME: "`date +%H:%M:%S`
	gzip $backupdirectory/$directoryname/$fullbackuplogname
	logmessage "Done. Created $backupdirectory/$directoryname/$fullbackupname"
	logmessage "To view the log, type:"
	logmessage " zcat $backupdirectory/$directoryname/$fullbackuplogname"
}


incrementalbackup()
{
	mailsubject=$incrementalbackuplabel

	# create variable with date of last full backup
	lastfullbackupdatevar=`cat $backupdirectory/$directoryname/lastfullbackupdate`
	
	# check for existence of incremental backup
	if test -e "$backupdirectory/$directoryname/$incrementalbackupname"; then 
		logmessage "Your last incremental backup was less than 60 seconds ago."
		logmessage "Wait a minute and try again."
	else 
		# create incremental backup
		logmessage "Running tar..."
		starttime="STARTTIME: "`date +%H:%M:%S`
		logmessage "$starttime"
		$tar --create --label "$incrementalbackuplabel" --files-from $filesfrom --exclude-from $excludefrom --ignore-failed-read --after-date "$lastfullbackupdatevar" --absolute-names --verbose --gzip --file $backupdirectory/$directoryname/$incrementalbackupname > $backupdirectory/$directoryname/$incrementalbackuplogname 2>&1
		logmessage "$stoptime"
		stoptime="STOPTIME: "`date +%H:%M:%S`
		gzip $backupdirectory/$directoryname/$incrementalbackuplogname
		logmessage "Done. Created $backupdirectory/$directoryname/$incrementalbackupname"
		logmessage "To view the log, type:"
		logmessage " zcat $backupdirectory/$directoryname/$incrementalbackuplogname"
	fi
}


# --------------------------------------------------
# Trap errors and cleanup after us
# --------------------------------------------------
trap "echo 'Interrupted...cleaning up'; rm -rf ${tempfile}; exit 1" 1 2 15


# --------------------------------------------------
# Mount the backup location
# --------------------------------------------------
if ! test -e "$backupdirectory"; then
	/sbin/mount_smbfs //BLOMMA:'tank girl'@IAGO/BLOMMA /Volumes/blomma-1
fi


if test -e "$backupdirectory"; then
	# now perform the backup.
	logmessage "---------- Backup Script Running... ----------"

	if test `date +%u` = "Monday" && test ! -e "$backupdirectory/$directoryname"; then
		# if it is monday and you havent yet done a full backup, do so
		logmessage "Performing Weekly Full Backup..."
		fullbackup;
	elif test ! -e $backupdirectory/$directoryname/*full.tar.gz; then
		# if there is no current fullbackup, make one
		logmessage "No Current Full Backup - Performing Full Backup Now..."
		fullbackup;
	else
		# otherwise, do an incremental backup
		logmessage "Performing Incremental Backup..."
		incrementalbackup;
	fi # end if statement

	logmessage "---------- Backup Script Done ----------"

	cat $tempfile | $MSMTP $mailaddress
	#cat $tempfile | mail -s "$mailsubject" $mailaddress

	# Clean up
	rm -rf ${tempfile}

else

	logmessage "ERROR: Couldnt mount the backup dir $backupdirectory"
	logmessage "ERROR: Program terminated"

fi

#
# End of file
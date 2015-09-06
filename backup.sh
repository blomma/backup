#!/bin/bash

if [ $UID != 0 ]; then
	logmessage "Backup script must be invoked by root"
	exit 1
fi

# --------------------------------------------------
# set variables:
# --------------------------------------------------
backupdirectory=/smb/maja.local/Factory/backup
directoryname=berry/"Week_"`date +%V`
fullbackuplabel="Full Backup of "`hostname`" on "`date '+%B %e, %Y'`
fullbackupname=`date +%Y-%m-%d`"_full.tar.gz"
fullbackuplogname=`date +%Y-%m-%d`"_full.log"
incrementalbackuplabel="Incremental Backup of "`hostname`" on "`date '+%B %e, %Y'`
incrementalbackupname=`date +%Y-%m-%d`"_incremental"`date +%H%M`".tar.gz"
incrementalbackuplogname=`date +%Y-%m-%d`"_incremental"`date +%H%M`".log"
filesfrom=~/.whattobackup
excludefrom=~/.whatnottobackup
tar=/usr/bin/tar

# --------------------------------------------------
# functions:
# --------------------------------------------------
logmessage()
{
	logger $1
}

fullbackup()
{
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
	$tar --one-file-system --create  --label "$fullbackuplabel" --files-from $filesfrom --exclude-from $excludefrom --ignore-failed-read --absolute-names --verbose --gzip --file $backupdirectory/$directoryname/$fullbackupname > $backupdirectory/$directoryname/$fullbackuplogname 2>&1
	logmessage "$stoptime"
	stoptime="STOPTIME: "`date +%H:%M:%S`
	gzip $backupdirectory/$directoryname/$fullbackuplogname
	logmessage "Done. Created $backupdirectory/$directoryname/$fullbackupname"
	logmessage "To view the log, type:"
	logmessage " zcat $backupdirectory/$directoryname/$fullbackuplogname"
}

incrementalbackup()
{
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
		$tar --one-file-system --create --label "$incrementalbackuplabel" --files-from $filesfrom --exclude-from $excludefrom --ignore-failed-read --after-date "$lastfullbackupdatevar" --absolute-names --verbose --gzip --file $backupdirectory/$directoryname/$incrementalbackupname > $backupdirectory/$directoryname/$incrementalbackuplogname 2>&1
		logmessage "$stoptime"
		stoptime="STOPTIME: "`date +%H:%M:%S`
		gzip $backupdirectory/$directoryname/$incrementalbackuplogname
		logmessage "Done. Created $backupdirectory/$directoryname/$incrementalbackupname"
		logmessage "To view the log, type:"
		logmessage " zcat $backupdirectory/$directoryname/$incrementalbackuplogname"
	fi
}

if test -e "$backupdirectory"; then
	logmessage "Backup Script Running"

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
	fi

	logmessage "Trimming old backups"
	logmessage "Backup Script Done"
else
	logmessage "ERROR: Backup dir $backupdirectory doesn not exist"
	logmessage "ERROR: Program terminated"
fi

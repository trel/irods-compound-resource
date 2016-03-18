#!/bin/sh

#set -x

## Copyright (c) 2009 Data Intensive Cyberinfrastructure Foundation. All rights reserved.
## For full copyright notice please refer to files in the COPYRIGHT directory
## Written by Jean-Yves Nief of CCIN2P3 and copyright assigned to Data Intensive Cyberinfrastructure Foundation

# This script is a template which must be updated if one wants to use the universal MSS driver.
# Your working version should be in this directory server/bin/cmd/univMSSInterface.sh.
# Functions to modify: syncToArch, stageToCache, mkdir, chmod, rm, stat
# These functions need one or two input parameters which should be named $1 and $2.
# If some of these functions are not implemented for your MSS, just let this function as it is.
#

# Changelog:
# 2013-01-22 - V1.00 - RV - initial version
# 2013-05-28 - v1.01 - RV - Add logging of universal MSS driver to logfile
# 2014-01-29 - v1.02 - RV - Add usage of gridftp for copy of files etc.
# 2014-02-07 - v1.03 - RV - Do NOT copy empty files in the function "syncToArch".
# 2014-02-07 - v1.04 - RV - Rework to use more and smaller readable functions.
# 2014-02-17 - v1.05 - RV - Add extra check to see if creation of directory really failed.
#                           We now use 4 ruleservers so it might be a race condition when a directory is created.
# 2015-07-01 - v1.06 - RV - implement copy of files with "," in filename.
# 2015-07-16 - v1.07 - RV - implement logging of error messages during copy with gridftp.
# 2015-08-10 - v1.08 - RV - implement retries from dCache to iRODS during copy with gridftp.
# 2015-10-14 - v1.09 - RV - implement stat function as it is being used in iRODS 4.1.6.
# 2015-10-20 - v1.10 - RV - implement stat function for gridftp. Before it was only a simple stat

VERSION=v1.10
PROG=`basename $0`
DEBUG=3
ID=$RANDOM
STATUS="OK"

# define logfile location
LOGFILE=/var/log/irods/univMSSInterface.log

# parameter to define access to external storage
ACCESS=gridftp


# gridftp parameters 
# enable gridftp for communication and do not use NFS
GRIDFTPCOMMAND=/usr/bin/uberftp
# use a random ip address for a gridftp server
declare -a GRIFTPSERVERS=(`host gridftp.grid.sara.nl | awk '{print $4}'`)
GRIDFTPIPADDRESSRANDOM=$(( $RANDOM % ${#GRIFTPSERVERS[@]} ))
GRIDFTPADDRESS="${GRIFTPSERVERS[$GRIDFTPIPADDRESSRANDOM]}"
GRIDFTPSERVERNAME=`host $GRIDFTPADDRESS | awk '{print $NF}' | sed 's/\.$//'`
GRIDFTPURL="gsiftp://${GRIDFTPSERVERNAME}"
GRIDFTPMINIMALSTRING="/pnfs/grid.sara.nl/data/irods" 


#############################################
# functions to do the actions 
#############################################

# function for the synchronization of file $1 on local disk resource to file $2 in the MSS
syncToArch () {
	# <your command or script to copy from cache to MSS> $1 $2 
	# e.g: /usr/local/bin/rfcp $1 rfioServerFoo:$2
	# /bin/cp "$1" "$2"
	_log 2 syncToArch "entering syncToArch()=$*"

	#sourceFile=$1
	#destFile=$2

	# assign parameters and make sure a file with "," is copied
	# add "\" before a "," in the filename
	sourceFile=$(echo $1 | sed -e 's/,/\\,/g')
	destFile=$(echo $2 | sed -e 's/,/\\,/g')
	error=0

	if [ -s $1 ] 
	then
		# so we have a NON-empty file. Copy it
		case ${ACCESS} in
			gridftp) # Use gridftp to do transfers
					syncToArchGridftp $sourceFile $destFile
					error=$?
					;;
			cp) # Use cp to do transfers
				syncToArchCp $sourceFile $destFile
				error=$?
				;;
			*) # an error
				_log 2 syncToArch "Unknown access method to storage"
				error=1
				;;
		esac
	else
		_log 2 syncToArch "file \"$1\" is empty. Do not copy an empty file"
		error=1
	fi

	if [ $error != 0 ] # copy failure 
	then
		STATUS="FAILURE"
	fi
	_log 2 syncToArch "The status is $error ($STATUS):"
	return $error
}


# function for staging a file $1 from the MSS to file $2 on disk
stageToCache () {
	# <your command to stage from MSS to cache> $1 $2	
	# e.g: /usr/local/bin/rfcp rfioServerFoo:$1 $2
	_log 2 stageToCache "entering stageToCache()=$*"

	#sourceFile=$1
	#destFile=$2

	# assign parameters and make sure a file with "," is copied
	# add "\" before a "," in the filename
	sourceFile=$(echo $1 | sed -e 's/,/\\,/g')
	destFile=$(echo $2 | sed -e 's/,/\\,/g')
	error=0

	case ${ACCESS} in
		gridftp) # Use gridftp to do transfers
				stageToCacheGridftp $sourceFile $destFile
				error=$?
				;;
		cp) # Use cp to do transfers
			stageToCacheCp $sourceFile $destFile
			error=$?
			;;
		*) # an error
			_log 2 stageToCache "Unknown access method to storage"
			error=1
			;;
	esac

	if [ $error != 0 ] # copy failure 
	then
		STATUS="FAILURE"
	fi
	_log 2 stageToCache "The status is $error ($STATUS)"
	return $error
}


# function to create a new directory $1 in the MSS logical name space
mkdir () {
	# <your command to make a directory in the MSS> $1
	# e.g.: /usr/local/bin/rfmkdir -p rfioServerFoo:$1
	_log 2 mkdir "entering mkdir()=$*"

	destDir=$1
	error=0

	case ${ACCESS} in
		gridftp) # Use gridftp make directory
				mkdirGridftp $destDir
				error=$?
				;;
		cp) # Use cp to make directory
			mkdirCp $destDir
			error=$?
			;;
		*) # an error
			_log 2 mkdir "Unknown access method to storage"
			error=1
			;;
	esac

	if [ $error != 0 ] # mkdir failure 
	then
		STATUS="FAILURE"
	fi
	_log 2 mkdir "The status is $error ($STATUS)"
	return $error
}


# function to modify ACLs $2 (octal) in the MSS logical name space for a given directory $1 
chmod () {
	# <your command to modify ACL> $1 $2
	# e.g: /usr/local/bin/rfchmod $2 rfioServerFoo:$1
	_log 2 chmod "entering chmod()=$*"

	destFile=$1
	destAcl=$2
	error=0

	case ${ACCESS} in
		gridftp) # Use gridftp to set ACL on file or directory
				chmodGridftp $destFile  $destAcl
				error=$?
				;;
		cp) # Use cp to set ACL on file or directory
			chmodCp $destFile $destAcl
			error=$?
			;;
		*) # an error
			_log 2 chmod "Unknown access method to storage"
			error=1
			;;
	esac

	if [ $error != 0 ] # chmod failure 
	then
		STATUS="FAILURE"
	fi
	_log 2 chmod "The status is $error ($STATUS)"
	return $error
}


# function to remove a file $1 from the MSS
rm () {
	# <your command to remove a file from the MSS> $1
	# e.g: /usr/local/bin/rfrm rfioServerFoo:$1
	_log 2 rm "entering rm()=$*"

	#destFile=$1

	# assign parameters and make sure a file with "," is removed
	# add "\" before a "," in the filename
	destFile=$(echo $1 | sed -e 's/,/\\,/g')
	error=0

	case ${ACCESS} in
		gridftp) # Use gridftp to remove a file
				rmGridftp $destFile 
				error=$?
				;;
		cp) # Use cp to remove a file
			rmCp $destFile
			error=$?
			;;
		*) # an error
			_log 2 rm "Unknown access method to storage"
			error=1
			;;
	esac

	if [ $error != 0 ] # rm failure 
	then
		STATUS="FAILURE"
	fi
	_log 2 rm "The status is $error ($STATUS)"
	return $error
}


# function to rename a file $1 into $2 in the MSS
mv () {
       # <your command to rename a file in the MSS> $1 $2
       # e.g: /usr/local/bin/rfrename rfioServerFoo:$1 rfioServerFoo:$2
	_log 2 mv "entering mv()=$*"

	#sourceFile=$1
	#destFile=$2

	# assign parameters and make sure a file with "," is moved
	# add "\" before a "," in the filename
	sourceFile=$(echo $1 | sed -e 's/,/\\,/g')
	destFile=$(echo $2 | sed -e 's/,/\\,/g')
	error=0

	case ${ACCESS} in
		gridftp) # Use gridftp to move a file
				mvGridftp $sourceFile $destFile 
				error=$?
				;;
		cp) # Use cp to move a file
			mvCp $sourceFile $destFile
			error=$?
			;;
		*) # an error
			_log 2 mv "Unknown access method to storage"
			error=1
			;;
	esac

	if [ $error != 0 ] # mv failure 
	then
		STATUS="FAILURE"
	fi
	_log 2 mv "The status is $error ($STATUS)"
	return $error
}


# function to do a stat on a file $1 stored in the MSS
stat () {
	# <your command to retrieve stats on the file> $1
	# e.g: output=`/usr/local/bin/rfstat rfioServerFoo:$1`
	_log 2 stat "entering stat()=$*"

	sourceFile=$(echo $1 | sed -e 's/,/\\,/g')
	error=0

	case ${ACCESS} in
		gridftp) # Use gridftp to move a file
				statGridftp $sourceFile
				error=$?
				;;
		cp) # Use cp to move a file
			statCp $sourceFile
			error=$?
			;;
		*) # an error
			_log 2 stat "Unknown access method to storage"
			error=1
			;;
	esac

	if [ $error != 0 ] # stat failure
	then
		STATUS="FAILURE"
	fi
	_log 2 stat "The status is $error ($STATUS)"
	return $error
}


#############################################
# helper functions to do the actual actions 
#############################################

_log() {
	TS=`date +"%Y:%m:%d-%T.%N "`
	level=$1; shift
	function=$1; shift
	if [ $level -lt $DEBUG ] ; then
		echo "$TS $ID $PROG[$$][$VERSION,$function,d${level}]: ${command}: $*" >>$LOGFILE 2>&1
	fi
}

syncToArchGridftp () {
	# helper function gridftp
	# <your command or script to copy from cache to MSS> $1 $2 
	# sourceFile=$1
	# destFile=$2

	error=0

	$GRIDFTPCOMMAND -dir "${GRIDFTPURL}$2"  > /dev/null 2>&1
	if [ $? = 0 ]
	then
		_log 2 syncToArch "file \"$2\" already exists. Remove it"
		_log 2 syncToArch "executing: $GRIDFTPCOMMAND -rm \"${GRIDFTPURL}$2\""
		$GRIDFTPCOMMAND -rm "${GRIDFTPURL}$2"
	fi

	_log 2 syncToArch "executing: $GRIDFTPCOMMAND \"file:$1\"  \"${GRIDFTPURL}$2\""
	status=$($GRIDFTPCOMMAND "file:$1" "${GRIDFTPURL}$2"   2>&1)
	error=$?

	if [ $error != 0 ] # syncToArch failure 
	then
		_log 2 syncToArch "error-message: $status"
	fi 

	return $error
}

syncToArchCp () {
	# helper function normal cp
	# <your command or script to copy from cache to MSS> $1 $2 
	# sourceFile=$1
	# destFile=$2

	error=0

	if [ -e "$2" ]
	then
		_log 2 syncToArch "file \"$2\" already exists. Remove it"
		_log 2 syncToArch "executing: /bin/rm \"$2\""
		/bin/rm  "$2"
	fi

	_log 2 syncToArch "executing: /bin/cp -f \"$1\" \"$2\""
	/bin/cp -f "$1" "$2"
	error=$?

	return $error
}

stageToCacheGridftp () {
	# helper function gridftp
	# <your command or script to copy from MSS to cache> $1 $2 
	# sourceFile=$1
	# destFile=$2

	error=0
	count="1"

	_log 2 stageToCache "executing: $GRIDFTPCOMMAND -wait \"${GRIDFTPURL}$1\" \"file:$2\"" 

	while true
	do
		status=$($GRIDFTPCOMMAND -wait "${GRIDFTPURL}$1" "file:$2"  2>&1)
		error=$?
		count=$[$count+1]

		# exit while loop if gridftp copy done without an error, or 3 tries.
		if [ $error = 0 -o $count -gt 3 ]
		then
			break
		fi

		# implement a sleep between retries
		sleep 1

		_log 2 stageToCache "executing: $GRIDFTPCOMMAND -wait \"${GRIDFTPURL}$1\" \"file:$2\", try number $count" 
	done

	if [ $error != 0 ] # stageToCache failure 
	then
		_log 2 stageToCache "error-message: $status"
	fi 

	return $error
}

stageToCacheCp () {
	# helper function cp
	# <your command or script to copy from  MSS to cache> $1 $2 
	# sourceFile=$1
	# destFile=$2

	error=0

	_log 2 stageToCache "executing: /bin/cp \"$1\" \"$2\""
	/bin/cp "$1" "$2"
	error=$?

	return $error
}

mkdirGridftp () {
	# helper function gridftp
	# <your command to make a directory in the MSS> $1
	# destDir=$1

	# Use gridftp to do transfers
	# this needs to be a loop because it can't create intermidiate directory's.
	_log 2 mkdir "executing: $GRIDFTPCOMMAND -dir \"${GRIDFTPURL}$1\""
	$GRIDFTPCOMMAND -dir "${GRIDFTPURL}$1"  > /dev/null 2>&1
	error=$?
	if [ $error = 0 ]
	then
		_log 2 mkdir "dir \"$1\" already exists. Not recreating directory"
	else
		count=0 
		TEMPDIR[$count]="$1"

		# find directory's to create
		# stop checking if we reach "/pnfs/grid.sara.nl/data/irods" or the directory exists.
		# Before this we can not create directory's
		while [ $error != 0 ]
		do
			DIR=$(dirname ${TEMPDIR[$count]})
			if [ "$GRIDFTPMINIMALSTRING" = "$DIR" ] 
			then
				_log 2 mkdir "do not check \"${GRIDFTPURL}$DIR\". It is part of the existing directory's"
				error=0
			else
				_log 2 mkdir "executing: $GRIDFTPCOMMAND -dir \"${GRIDFTPURL}$DIR\""
				$GRIDFTPCOMMAND -dir "${GRIDFTPURL}$DIR"  > /dev/null 2>&1
				error=$?
				if [ $error != 0 ]
				then
					let count+=1
					TEMPDIR[$count]=$DIR
				fi
			fi
		done

		# create needed directory's
		until [ $count -lt 0 ]
		do
			_log 2 mkdir "executing: $GRIDFTPCOMMAND -mkdir \"${GRIDFTPURL}${TEMPDIR[$count]}\""
			$GRIDFTPCOMMAND -mkdir "${GRIDFTPURL}${TEMPDIR[$count]}"
			error=$?
			let count-=1
		done
	fi

	# we have a failure of the creation. Let's check if it really is a failure
	if [ $error != 0 ]
	then
		# check if the directory has been created properly
		_log 2 mkdir "Rechecking if dir \"$1\" already exists. There was a problem during the creation of the directory"
		$GRIDFTPCOMMAND -dir "${GRIDFTPURL}$1"  > /dev/null 2>&1
		error=$?
		if [ $error = 0 ]
		then
			_log 2 mkdir "dir \"$1\" was properly created. Probably a race condition in irods/gridftp/dCache"
		fi
	fi

	return $error
}

mkdirCp () {
	# helper function cp
	# <your command to make a directory in the MSS> $1
	# destDir=$1

	error=0

	if [ -d "$1" ]
	then
		_log 2 mkdir "directory \"$1\" already exists. Not recreating directory"
	else
		_log 2 mkdir "executing: /bin/mkdir -p \"$1\""
		/bin/mkdir -p "$1"
		error=$?
	fi

	return $error
}

chmodGridftp () {
	# helper function gridftp
	# <your command to modify ACL> $1 $2
	# destFile=$1
	# destAcl=$2

	error=0

	# Use gridftp to do transfers
	_log 2 chmod "pseudo executing: $GRIDFTPCOMMAND -chmod $2 \"${GRIDFTPURL}$1\""
	_log 2 chmod "pseudo executing: dCache makes it 700 anyway. It does not implement chmod"
	#$GRIDFTPCOMMAND -chmod $2 "${GRIDFTPURL}$1"
	#error=$?

	return $error
}

chmodCp () {
	# helper function cp
	# <your command to modify ACL> $1 $2
	# destFile=$1
	# destAcl=$2

	error=0

	_log 2 chmod "executing: /bin/chmod $2 \"$1\""
	/bin/chmod $2 "$1"
	error=$?

	return $error
}

rmGridftp () {
	# helper function gridftp
	# <your command to remove file> $1
	# destFile=$1

	error=0

	# Use gridftp to do transfers
	_log 2 rm "executing: $GRIDFTPCOMMAND -rm  \"${GRIDFTPURL}$1\""
	$GRIDFTPCOMMAND -rm  "${GRIDFTPURL}$1"
	error=$?

	return $error
}

rmCp () {
	# helper function cp
	# <your command to remove file> $1
	# destFile=$1

	error=0

	_log 2 rm "executing: /bin/rm \"$1\""
	/bin/rm "$1"
	error=$?

	return $error
}

mvGridftp () {
	# helper function gridftp
	# <your command to rename a file in the MSS> $1 $2
	#sourceFile=$1
	#destFile=$2
	
	error=0

	# Use gridftp to do transfers
	_log 2 mv "executing: $GRIDFTPCOMMAND \"${GRIDFTPURL}$1\"  \"${GRIDFTPURL}$2\""
	$GRIDFTPCOMMAND "${GRIDFTPURL}$1" "${GRIDFTPURL}$2"
	error=$?
	if [ $error != 0 ] # mv failure 
	then
		_log 2 mv "executing: $GRIDFTPCOMMAND \"${GRIDFTPURL}$1\"  \"${GRIDFTPURL}$2\" failed"
	else
		_log 2 mv "executing: $GRIDFTPCOMMAND -rm  \"${GRIDFTPURL}$1\""
		$GRIDFTPCOMMAND -rm  "${GRIDFTPURL}$1"
		error=$?
	fi

	return $error
}

mvCp () {
	# helper function cp
	# <your command to rename a file in the MSS> $1 $2
	#sourceFile=$1
	#destFile=$2

	error=0

	_log 2 mv "executing: /bin/mv \"$1\" \"$2\""
    /bin/mv "$1" "$2"
	error=$?

	return $error
}

statGridftp () {
	# helper function gridftp
	# <your command to stat a file in the MSS $1
	#sourceFile=$1
	
	error=0

	# Use gridftp to do transfers
	_log 2 stat "executing: $GRIDFTPCOMMAND -dir \"${GRIDFTPURL}$1\""
	output=`$GRIDFTPCOMMAND -dir "${GRIDFTPURL}$1" 2>&1`
	error=$?
	if [ $error != 0 ] # stat failure 
	then
		_log 2 stat "executing: $GRIDFTPCOMMAND -dir \"${GRIDFTPURL}$1\"  failed"
	else
		# parse the output.
		# Parameters to retrieve: device ID of device containing file("device"), 
		#                         file serial number ("inode"), ACL mode in octal ("mode"),
		#                         number of hard links to the file ("nlink"),
		#                         user id of file ("uid"), group id of file ("gid"),
		#                         device id ("devid"), file size ("size"), last access time ("atime"),
		#                         last modification time ("mtime"), last change time ("ctime"),
		#                         block size in bytes ("blksize"), number of blocks ("blkcnt")
		# e.g: device=`echo $output | awk '{print $3}'`	
		# Note 1: if some of these parameters are not relevant, set them to 0.
		# Note 2: the time should have this format: YYYY-MM-dd-hh.mm.ss with: 
		#                                           YYYY = 1900 to 2xxxx, MM = 1 to 12, dd = 1 to 31,
		#                                           hh = 0 to 24, mm = 0 to 59, ss = 0 to 59
		device="0"
		inode="0"
		mode=`echo $output | awk '{print $1}' | awk '{k=0;for(i=0;i<=8;i++)k+=((substr($1,i+2,1)~/[drwxt]/)*2^(8-i));if(k)printf("%0o",k)}'`
		nlink=`    echo $output | awk '{print $2}'`
		uid_output=`    echo $output | awk '{print $3}'`
		uid=`id -u $uid_output`
		gid_output=`    echo $output | awk '{print $4}'`
		gid=`id -g $gid_output`
		devid="0"
		size=`   echo $output | awk '{print $5}'`
		blksize="0"
		blkcnt="0"
		month=`  echo $output | awk '{ print $6}'`
        month=`awk -v "month=$month" 'BEGIN {months = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"; printf "%02d", (index(months, month) + 3) / 4}'`
		day=`    echo $output | awk '{ printf "%02d", $7}'`
		yearTime=`   echo $output | awk '{ print $8}'`
		hour="00"
        minute="00"
		case "$yearTime" in
			*:*)
				year=`date +%Y`
                hour=`echo $yearTime | awk -F: '{print $1}'`
                minute=`echo $yearTime | awk -F: '{print $2}'`
				;;
			*)
				year=$yearTime
				;;
		esac
		atime=`echo "$year-$month-$day-$hour.$minute.00" `
		mtime=$atime
		ctime=$atime
		echo "$device:$inode:$mode:$nlink:$uid:$gid:$devid:$size:$blksize:$blkcnt:$atime:$mtime:$ctime"
 
	fi

	return $error
}


# function to do a stat on a file $1 stored in the MSS
statCp () {
	# helper function stat
	# <your command to retrieve stats on the file> $1
	# e.g: output=`/usr/local/bin/rfstat rfioServerFoo:$1`

	error=0

	_log 2 stat "executing: /usr/bin/stat \"$1\" "
	output=`/usr/bin/stat "$1"`
	error=$?
	if [ $error != 0 ] # if file does not exist or information not available
	then
		STATUS="FAILURE"
		_log 2 stat "executing: stat command failed"
	else
		# parse the output.
		# Parameters to retrieve: device ID of device containing file("device"), 
		#                         file serial number ("inode"), ACL mode in octal ("mode"),
		#                         number of hard links to the file ("nlink"),
		#                         user id of file ("uid"), group id of file ("gid"),
		#                         device id ("devid"), file size ("size"), last access time ("atime"),
		#                         last modification time ("mtime"), last change time ("ctime"),
		#                         block size in bytes ("blksize"), number of blocks ("blkcnt")
		# e.g: device=`echo $output | awk '{print $3}'`	
		# Note 1: if some of these parameters are not relevant, set them to 0.
		# Note 2: the time should have this format: YYYY-MM-dd-hh.mm.ss with: 
		#                                           YYYY = 1900 to 2xxxx, MM = 1 to 12, dd = 1 to 31,
		#                                           hh = 0 to 24, mm = 0 to 59, ss = 0 to 59
		device=` echo $output | sed -nr 's/.*\<Device: *(\S*)\>.*/\1/p'`
		inode=`  echo $output | sed -nr 's/.*\<Inode: *(\S*)\>.*/\1/p'`
		mode=`   echo $output | sed -nr 's/.*\<Access: *\(([0-9]*)\/.*/\1/p'`
		nlink=`  echo $output | sed -nr 's/.*\<Links: *([0-9]*)\>.*/\1/p'`
		uid=`    echo $output | sed -nr 's/.*\<Uid: *\( *([0-9]*)\/.*/\1/p'`
		gid=`    echo $output | sed -nr 's/.*\<Gid: *\( *([0-9]*)\/.*/\1/p'`
		devid="0"
		size=`   echo $output | sed -nr 's/.*\<Size: *([0-9]*)\>.*/\1/p'`
		blksize=`echo $output | sed -nr 's/.*\<IO Block: *([0-9]*)\>.*/\1/p'`
		blkcnt=` echo $output | sed -nr 's/.*\<Blocks: *([0-9]*)\>.*/\1/p'`
		atime=`  echo $output | sed -nr 's/.*\<Access: *([0-9]{4,}-[01][0-9]-[0-3][0-9]) *([0-2][0-9]):([0-5][0-9]):([0-6][0-9])\..*/\1-\2.\3.\4/p'`
		mtime=`  echo $output | sed -nr 's/.*\<Modify: *([0-9]{4,}-[01][0-9]-[0-3][0-9]) *([0-2][0-9]):([0-5][0-9]):([0-6][0-9])\..*/\1-\2.\3.\4/p'`
		ctime=`  echo $output | sed -nr 's/.*\<Change: *([0-9]{4,}-[01][0-9]-[0-3][0-9]) *([0-2][0-9]):([0-5][0-9]):([0-6][0-9])\..*/\1-\2.\3.\4/p'`
		echo "$device:$inode:$mode:$nlink:$uid:$gid:$devid:$size:$blksize:$blkcnt:$atime:$mtime:$ctime"
	fi

    return $error
}


#############################################
# below this line, nothing should be changed.
#############################################

case "$1" in
	syncToArch ) $1 $2 $3 ;;
	stageToCache ) $1 $2 $3 ;;
	mkdir ) $1 $2 ;;
	chmod ) $1 $2 $3 ;;
	rm ) $1 $2 ;;
	mv ) $1 $2 $3 ;;
	stat ) $1 $2 ;;
esac

exit $?

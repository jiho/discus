#!/bin/bash
#
#   Library of shell functions used repeatedly in DISCUS
#
#  (c) Copyright 2009 Jean-Olivier Irisson.
#  GNU General Public License
#  Read the file 'src/GNU_GPL.txt' for more information
#
#------------------------------------------------------------------------------

#
# USAGE
#	help
# Displays a help message
#
help() {
echo -e "
\033[1mUSAGE\033[0m
  \033[1m$0 [options] [parameters]\033[0m action[s] deployment
  Data extraction and analysis script for the DISC.
  Actions perform a data analysis step and are whole or abbreviated words.
  Options modify the behaviour of the script and are prepended a \"-\" sign.
  Deployment numbers can be specified as ranges: 1,3-5,8

\033[1mACTIONS\033[0m
  \033[1mh, help\033[0m          display this help message
  \033[1mstatus\033[0m           prints information about the deployments
  \033[1mget\033[0m              get data from the storage to the workspace
  \033[1mstore\033[0m            move data from the workspace to the storage
  \033[1mv, video\033[0m         extract images from a video file
  \033[1mstab\033[0m             stabilize the image sequence
  \033[1mcal, calib\033[0m       measure calibration data for the tracking
  \033[1mcom, compass\033[0m     track the compass manually
  \033[1ml, larva\033[0m         track the larva(e) manually
  \033[1mc, correct\033[0m       correct the tracks
  \033[1ms, stats\033[0m         compute statistics and plots
  \033[1mall\033[0m              calibrate, track larva, correct and compute stats

\033[1mOPTIONS\033[0m
  Each lines give the options, the action it is applicable to,
  and its default when it requires a value.
  \033[1m-s\033[0m         status     get status of the storage directory instead
  \033[1m-sub\033[0m      v,l,com  1  image subsample interval, in seconds
  \033[1m-psub\033[0m       stats  5  subsample positions every 'psub' seconds
                        (has no effect when < to -sub)
  \033[1m-bin\033[0m        stats  0  angle over which to bin angles, in degrees
  \033[1m-d|-display\033[0m stats     display the plots after stats

\033[1mPARAMETERS\033[0m
  Parameters are written in the configuration file after they are set.
  Therefore, they \"stick\" from one run to the other.
  \033[1m-work\033[0m      .     working directory, containing deployments
  \033[1m-storage\033[0m   none  image and data storage directory
  \033[1m-diam\033[0m      40    aquarium diameter, in cm
  \033[1m-a|-angle\033[0m  90    angle between camera and compass, in degrees
  \033[1m-m|-mem\033[0m    1000  memory for Image, in MB
                   (should be at most a 2/3 of the physical memory)
   "

	return 0
}


#
# USAGE
#	commit_changes [files_to_commit]
# Ask to commit changes and copy specified files from $tmp to $data
# The environment variables $tmp, $data, and $yes must be already defined
#
commit_changes() {
	if [[ $tmp == "" ]]; then
		error "Temporary directory undefined"
		exit 1
	fi
	if [[ $data == "" ]]; then
		error "Deployment directory undefined"
		exit 1
	fi
	echoB "Committing changes"
	if [[ $yes == "TRUE" ]]; then
		# when $yes is true, we don't ask and assume we want to commit
		commit="yes"
	else
		read -p "Do you want to commit changes? (y/n [n]) : " commit
	fi
	if yes $commit;	then
		echo "Moving data..."
		# perform shell expansion on the parameters passed to commit_changes
		# this allows to pass plot*.pdf and have all plot-1.pdf, plot-2.pdf etc. copied
		allItems=$(cd $tmp; echo $@)

		# move the files interactively to the DATA directory
		# i.e. we want to explicitly ask for overwrites except when "yes" is true
		for item in $allItems; do
			# check for existence
			if [[ -e $tmp/$item ]]; then
				# directories do not work well with mv -i
				# so we cook our own interactive directory overwrite
				if [[ $yes == "TRUE" ]]; then
					mv -f $tmp/$item $data
				else
					# if the directory exists in both locations, ask whether to overwrite
					if [[ -d $tmp/$item && -d $data/$item ]]; then
						read -p "mv: overwrite \`${data}/$item'? " overwrite
						if yes $overwrite; then
							rm -f $data/$item/*
							rmdir $data/$item
							mv $tmp/$item $data
						fi
						# NB: if we do not want to overwrite then we just loop to the next item
					else
						# for files or non-existing directories, we simply use mv -i
						mv -i $tmp/$item $data
					fi
				fi
			else
				warning "$item does not exist"
			fi
			# go to the next argument
			shift 1
		done
	else
		echo "OK, cleaning TEMP directory then..."
	fi
	# clean temp directory
	if [[ -d $tmp ]]; then
		rm -Rf $tmp/*
	fi

	return 0
}


#
# USAGE
#	data_status [data_directory]
# Prints some status information about the content of the data directory
#
data_status() {
	work=$1

	echo -e "\n\033[1mdepl   vid img   com gps ctd   cal trk lag sta sub\033[0m"

	for i in `ls -1 $work/ | sort -n`; do

		# display deploy number
		echo "$i" | awk {'printf("%-5s",$1)'}
		# use awk for nicely formatted output

		# test the existence of video
		if [[ -e $work/$i/video_hifi.mov ]]; then
			echo -n "   *  "
		else
			echo -n "      "
		fi

		# count images
		nbImages=$(ls 2>/dev/null $work/$i/pics/*.jpg | wc -l)
		if [[ ! $? ]]; then
			nbImages=0
		fi
		echo "$nbImages" |  awk {'printf("%-5s",$1)'}

		# test the existence of data files
		if [[ -e $work/$i/compass_log.csv ]]; then
			echo -n "  * "
		elif [[ -e $work/$i/coord_compass.txt && -e $work/$i/compass_track.txt ]]; then
			echo -n " man"
		else
			echo -n "    "
		fi
		if [[ -e $work/$i/gps_log.csv ]]; then
			echo -n "  * "
		else
			echo -n "    "
		fi
		if [[ -e $work/$i/ctd_log.csv ]]; then
			echo -n "  * "
		else
			echo -n "    "
		fi

		echo -n " "
		# test the existence of result files
		if [[ -e $work/$i/coord_aquarium.txt ]]; then
			echo -n "   * "
		else
			echo -n "     "
		fi
		if [[ -e $work/$i/tracks.csv ]]; then
			echo -n "  * "
		elif [[ -e $work/$i/larvae_track.txt ]]; then
			echo -n " raw"
		else
			echo -n "    "
		fi
		# get the lag between images in seconds

		# when the corrected track is available, use the times there
		if [[ -e $work/$i/tracks.csv ]]; then
			# with R read the corrected tracks and compute average time difference
			R -q --slave << EOF
				# read only the beginning of the file to speed things up
				t = read.table("${work}/${i}/tracks.csv", header=T, sep=",", as.is=T, nrows=400)
				# set the correct time class and remove missing values
				imgTimes = as.POSIXct(na.omit(t\$date))
				# compute the average time difference
				cat(sprintf("%4i",round(mean(diff(imgTimes)))))
EOF

		# otherwise fall back on the uncorrected track
		# but in this case times have to be extracted from the image files
		elif [[ -e $work/$i/larvae_track.txt ]]; then
			# read the track, get the numbers of the images on which a larva was detected
			# select the first 3 lines, remove the header, and select 4th column
			imgNbs=$(head -n 3 $work/$i/larvae_track.txt | sed \1d | awk -F "\t" {'print $4'})
			# this selects only the first 2 images but using more slows things down when exiftool reads the creation date

			# re-construct the full paths to images
			images=$(echo $imgNbs | awk '{OFS=""; print pics,$1,".jpg ",pics,$2,".jpg"}' pics="${work}/${i}/pics/")

			# compute the time difference in R
			R -q --slave << EOF
				# get images capture times with exiftool
				imgTimes = system("exiftool -T -CreateDate ${images}", intern=T)
				# compute the time difference
				imgTimes = as.POSIXct(imgTimes,format="%Y:%m:%d %H:%M:%S")
				cat(sprintf("%4i",as.numeric(diff(imgTimes))))
EOF
		else
			echo -n "    "
		fi
		if [[ -e $work/$i/stats.csv ]]; then
			echo -n "  * "
		else
			echo -n "    "
		fi
		
		# display subsample interval
		if [[ -e $work/$i/stats.csv ]]; then
			R -q --slave << EOF
			# read the stats
			s = read.table("${work}/${i}/stats.csv", header=T, sep=",", as.is=T, nrows=1)
			if (is.na(s[1,"resample.lag"])) {
				cat("  - ")
			} else {
				cat(sprintf("%4i",s[1,"resample.lag"]))
			}
EOF
			echo -n ""
		else
			echo -n "    "
		fi

		echo ""

	done

	return 0
}


#
# USAGE
#	sync_data [data_directory] [storage_directory] [action] [deployment_id]
# Synchronize data between data and storage directories/drives
#
sync_data() {
	work=$1
	storage=$2
	action=$3
	id=$4

	# RSync options to test for differences
	# for small files we use checksum and time comparison
	rsoptsSmall="--recursive --checksum --update --exclude=.* --exclude=*tmp/ --exclude=*pics/ --exclude=*.mov"
	# for large files we use size only comparison (which is faster)
	rsoptsLarge="--recursive --size-only --exclude=*tmp/ --include=*/ --include=*.jpg --include=*.mov --exclude=*"


	# GET DATA FROM STORAGE
	if [[ $action == "get" ]]; then

		# Check the existence of the deployment
		if [[ ! -e $storage/$id ]]; then
			error "Deployment $id does not exist in storage:\n  $storage"
			exit 1
		fi

		# Update or move data
		if [[ -e $work/$id ]]; then
			# The deployment exists in the workspace
			# First do a test run, ask for confirmation and then proceed to the real run

			diffS=$(rsync --dry-run --delete --out-format="  %o %n" $rsoptsSmall $storage/$id/ $work/$id)
			diffL=$(rsync --dry-run --delete --out-format="  %o %n" $rsoptsLarge $storage/$id/ $work/$id)
			if [[ ${diffS}${diffL} == "" ]]; then
				echo "Already up-to-date"
			else
				echoB "Working directory <- Storage"
				echo "The transfers about to occur are:"
				if [[ $diffS != "" ]]; then echo "$diffS"; fi
				if [[ $diffL != "" ]]; then echo "$diffL"; fi
				read -p "Do you want to proceed? (y/n [n]) " proceed
				if yes $proceed; then
					echo "Update deployment $id"
					rsync --delete $rsoptsSmall $storage/$id/ $work/$id
					rsync --delete $rsoptsLarge $storage/$id/ $work/$id
				else
					echo "Skipping transfer"
				fi
			fi

		else
			# The deployment does not exist in the workspace
			# = we want to copy data from the storage to the working dir
			echo -e "\033[1mWorking directory <- Storage\033[0m : copy deployment $id"
			rsync -a $storage/$id $work
			# NB : preserve modification time etc.
		fi

	fi

	# MOVE DATA TO STORAGE
	if [[ $action == "store" ]]; then

		# Check the existence of the deployment
		if [[ ! -e $work/$id ]]; then
			error "Deployment $id does not exist in working directory:\n  $work"
			exit 1
		fi

		# Update or move data
		if [[ -e $storage/$id ]]; then
			# the deployment exist in the storage
			# First do a test run, ask for confirmation and then proceed to the real run
			diffS=$(rsync --dry-run --delete --out-format="  %o %n" $rsoptsSmall $work/$id/ $storage/$id)
			diffL=$(rsync --dry-run --delete --out-format="  %o %n" $rsoptsLarge $work/$id/ $storage/$id)
			# for information, test whether some result files are newer or only present in storage
			diffSsw=$(rsync --dry-run --out-format="    %n" $rsoptsSmall $storage/$id/ $work/$id)
			if [[ ${diffS}${diffSsw}${diffL} == "" ]]; then
				echo "Already up-to-date"
			else
				echoB "Working directory -> Storage"
				if [[ $diffSsw != "" ]]; then
					warning "The file(s)\n$diffSsw\n  are newer (or only present) in the storage"
				fi
				if [[ ${diffS}${diffL} != "" ]]; then
					# If there are some files left beyond those
					echo "The transfers about to occur are:"
					if [[ $diffS != "" ]]; then echo "$diffS"; fi
					if [[ $diffL != "" ]]; then echo "$diffL"; fi
					read -p "Do you want to proceed? (y/n [n]) " proceed
					if yes $proceed; then
						echo "Update deployment $id"
						rsync --delete $rsoptsSmall $work/$id/ $storage/$id
						rsync --delete $rsoptsLarge $work/$id/ $storage/$id
					else
						echo "Skipping transfer"
					fi
				fi
			fi

		else
			echoB "Working directory -> Storage"
			# The deployment does not exist in the storage
			# = there is possibly a problem in the storage path
			#   or we want to initialize a new backup directory
			warning "$storage/$id does not exist"
			echo -en "Do you \033[1mreally\033[0m want to create a new storage directory?"
			read -p " (y/n [n]) " proceed
			if yes $proceed; then
				echo "Create new storage for deployment $id"
				# Create parent directory
				mkdir -p $storage
				# Copy data, preserving time stamps etc.
				rsync -a $work/$id $storage
			else
				echo "Skipping transfer"
			fi
		fi

	fi

	return 0
}


#
# USAGE
#	read_config [path_to_configuration_file]
# Read a configuration file in valid bash syntax
# and give information on what is read
#
read_config() {
	configFile=$1

	echoBold "Options picked up from the configuration file"

	cat $configFile | while read line; do
		# Ignore comments and print other lines
		case $line in
			\#*)
				;;
			'')
				;;
			*)
				# Parse the line and give information on stdout
				echo "$line" | awk -F "=" {'print "  "$1" = "$2'}
				;;
		esac
	done
	echo ""

	# Actually source the file (i.e. set the options, don't just display them)
	source $configFile

	return 0
}

#
# USAGE
#	write_pref [file] [variable name]
# Write the current value of the variable in the preferences file.
# If the preference already exists, update it. otherwise, create it.
#
write_pref() {
	configFile=$1
	pref=$2		# this is only the name of the variable, i.e. a string

	# test whether the variable currently has a value
	if [[ $(eval echo \$$pref) == "" ]]; then
		error "$pref does not have a value"
		exit 1
	fi

	# test whether the preference already exists
	cat $configFile | grep "^[^#]*$pref" > /dev/null

	if [[ $? == "0"  ]]; then
		# if there is a match, update the preference in the config file
		tmpConf=configFile.new
		newPref=$(eval echo \$$pref)
		# escape slashes in the value of the preference
		newPref=$(echo $newPref | sed -e 's/\//\\\//g')
		sed -e 's/^\s*'$pref'=.*/'$pref'="'$newPref'"/' $configFile > $tmpConf
		cp -f $tmpConf $configFile
		rm -f $tmpConf
	else
		# otherwise, write the pref at the end of the file
		echo "$pref=\"$(eval echo \$$pref)\"" >> $configFile
	fi

	return 0
}

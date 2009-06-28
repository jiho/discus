#!/bin/bash
#
#	Functions useful at several stages of the analysis with DISCUS
#	- open images as a stack
#	- commit changes from the temporary directory to the data directory
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
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
  \033[1mstatus\033[0m           prints information about the working directory
  \033[1msync\033[0m             synchronize data between workspace and storage
  \033[1mv, video\033[0m         extract images from a video file
  \033[1mstab\033[0m             stabilize image sequence
  \033[1mcal, calib\033[0m       measure calibration data for the tracking
  \033[1mcom, compass\033[0m     track the compass manually
  \033[1ml, larva\033[0m         track the larva(e)
  \033[1mc, correct\033[0m       correct the tracks
  \033[1ms, stats\033[0m         compute statistics and plots
  \033[1mall\033[0m              calibrate, track larva, correct and compute stats

\033[1mOPTIONS\033[0m
  Each lines give the options, the action it is applicable to, 
  and its default when it requires a value.
  \033[1m-s\033[0m                    get status of the storage directory instead
  \033[1m-sub\033[0m  video,larva  1  subsample interval, in seconds
  \033[1m-psub\033[0m       stats  5  subsample positions every 'psub' seconds
                        (has no effect when < to -sub)
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
# Ask to commit changes and copy specified files from $TEMP to $DATA
# The environment variables $TEMP and $DATA must be already defined
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
	read -p "Do you want to commit changes? (y/n [n]) : " commit
	if yes $commit;	then
		echo "Moving data..."
		# perform shell expansion on the parameters passed to commit_changes
		# this allows to pass plot*.pdf and have all plot-1.pdf, plot-2.pdf etc. copied
		allItems=$(cd $tmp; echo $@)

		# move the files interactively to the DATA directory
		# i.e. we want to explicitly ask for overwrites
		for item in $allItems; do
			# check for existence
			if [[ -e $tmp/$item ]]; then
				# directories do not work well with mv -i
				# so we cook our own interactive directory overwrite
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

	echo -e "\n\e[1mdepl img   com gps ctd   cal trk sta\e[0m"

	for i in `ls -1 $work/ | sort -n`; do

		# display deploy number
		echo "$i" | awk {'printf("%-5s",$1)'}
		# use awk for nice formatted output

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
		if [[ -e $work/$i/stats.csv ]]; then
			echo -n "  * "
		else
			echo -n "    "
		fi

		echo ""

	done

	return 0
}


#
# USAGE
#	sync_data [data_directory] [storage_directory] [deployment_id]
# Synchronize data between data and storage directories/drives
#
sync_data()
{
	base=$1
	storage=$2
	id=$3

	# # Guess the storage directory (separate different campaigns)
	#
	# # use one of the deployNb
	# id=$(echo ${deployNb} | awk -F " " {'print $1'})
	#
	# # get the name of the 100th picture in the current data dir
	# pic=$(ls $base/$id/pics/ | sort -n | head -n 100 | tail -n 1)
	# # we use the 100th one because it is not too close from the beginning or the end, hence should be relatively robust if the beginning and end times are changed and the beginning or end pictures change
	#
	# # find a path that ends by this combination of id and pic
	# storage=$(find $storageRoot/DISC* -path *$id/pics/$pic)
	#
	# # suppress id and pic from the path to get the root for this id
	# storage=$(echo ${storage/\/$id\/pics\/${pic}/})


	if [[ -e $storage/$id ]]; then

		if [[ -e $base/$id ]]; then
			# SYNCHRONISATION
			# The deployment is present in the working dir and in the storage

			# First check whether picture files are identical in both

			# diff --brief $base/$id/pics/ $storage/$id/pics/
			# NB: diffing compares the content of files, which is lengthy for that many binary files.
			#     instead we use rsync which compares file size.
			#     rsync could also compare checksums (with the -c option).
			diffPic=$(rsync --dry-run -r --delete --size-only --out-format=%n --include='*.jpg' --exclude='*' $storage/$id/pics/ $base/$id/pics)
			# compares presence/absence of pictures, because of --recursive --delete
			#          picture file sizes, because of --size-only (not modif time)
			# outputs something when files are different, because of --out-format
			# NB: the presence or absence of "/" at the end of the paths is significant

			if [[ $diffPic != "" ]] ; then
				# When some pictures are different it is probably because something changed in the way the deployments are split from the daily data, or pictures were edited (add the north etc.).
				# In that case we want to warn the user, ask whether we should still copy the results, and copy the new pictures to the working dir

				warning "Some pictures are different between working and storage directories"

				# Update pictures in working directory
				echo -e "\e[1mWorking directory <- Storage\e[0m : update pictures"
				rsync -r --times --omit-dir-times --delete --size-only --out-format="  %o %n" --include='*.jpg' --exclude='*'  $storage/$id/pics/ $base/$id/pics

				# Ask the user whether we should still transfer results
				echo -e "Because of that, the results that are about to be copied from the working\ndirectory to the storage will not match the pictures there."
				read -p "Do you still want to copy them? (y/n [n]) " copyResults
			else
				copyResults="yes"
			fi

			# Pictures in working dir and storage are the same
			#   or
			# Pictures are different but we still want to copy results
			if yes $copyResults; then

				# Test whether the results have changed
				differences=$(rsync --dry-run -r --checksum --out-format="%n" --exclude='.*' --exclude='*tmp/' --exclude='*pics/' $base/$id/ $storage/$id)
				# NB: since the files are small here we do the most robust comparison, based on the checksum

				if [[ $differences = "" ]]; then
					echo "Already up-to-date."
				else
					# Copy results to storage
					echo -e "\e[1mWorking directory -> Storage\e[0m : store (or update) results files"
					rsync -r --times --omit-dir-times --owner --checksum --out-format="  %n" --exclude='.*' --exclude='*tmp/' --exclude='*pics/' $base/$id/ $storage/$id
				fi

			fi

		else

			# IMPORT PICTURES (and data actually, just copy everything)
			# The deployment is only present in the storage
			# = we want to copy pictures from the storage to the working dir
			echo -e "\e[1mWorking directory <- Storage\e[0m : copy deployment $id"
			cp -R --preserve=timestamps $storage/$id $base
			# NB : preserve attributes, timestamps, users etc.

		fi
	else

		if [[ -e $base/$id ]]; then

			# START NEW BACKUP
			# The deployment is only present in the working dir
			# = there is possibly a problem in the storage path
			#   or we want to initialize a new backup directory
			warning "$storage/$id does not exist"
			echo -en "Do you \e[1mreally\e[0m want to create a new storage directory?"
			read -p " (y/n [n]) " proceed
			if yes $proceed; then
				echo -e "\e[1mWorking directory -> Storage\e[0m : store deployment $id"
				# Create parent directory
				mkdir -p $storage
				# Copy data
				cp -R --preserve=timestamps $base/$id $storage
			else
				echo "Skipping $id"
			fi

		else

			# UNAVAILABLE DATA
			error "Cannot find deployment \"$id\" in\n    $base\n  or\n    $storage"
			return 1

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
		case $line in
			\#*)
				;;
			'')
				;;
			*)
				# Parse the line and give information
				echo "$line" | awk -F "=" {'print "  "$1" = "$2'}
				;;
		esac
	done
	echo ""

	# Actually source the file
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
		tmpConf=$(mktemp /tmp/bbconf.XXXXX)
		newPref=$(eval echo \$$pref)
		# espace slashes in the value of the preference
		newPref=$(echo $newPref | sed -e 's/\//\\\//g')
		sed -e 's/'$pref'=.*/'$pref'="'$newPref'"/' $configFile > $tmpConf
		cp -f $tmpConf $configFile
		rm -f $tmpConf
	else
		# otherwise, write the pref at the end of the file
		echo "$pref=\"$(eval echo \$$pref)\"" >> $configFile
	fi

	return 0
}

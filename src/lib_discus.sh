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
#	Display a help message
#
help() {
echo -e "
\033[1mUSAGE\033[0m
  \033[1m$0 [options] [parameters]\033[0m action[s] deployment
  Data extraction and analysis script for the DISC.
  Actions perform a data analysis step and are whole or abbreviated words.
  Options modify the behaviour of the script and are prepended a \"-\" sign.
  Deployment numbers can be specified as ranges: 1,3-5,8

\033[1mACTIONS / relevant OPTIONS\033[0m
  \033[1mh|help\033[0m            display this help message
  \033[1mstatus\033[0m            prints information about the data directory

  \033[1mcal|calib\033[0m         measure calibration data for the tracking
  \033[1mcom|compass\033[0m       track the compass manually
  \033[1ml|larva\033[0m           track the larva(e)
    \033[1m-sub\033[0m        1   subsample interval, in seconds
  \033[1mc|correct\033[0m         correct the tracks
  \033[1ms|stats\033[0m           compute statistics and plots
    \033[1m-psub\033[0m       5   subsample positions every 'psub' seconds
                    (has no effect when < to -sub above)
    \033[1m-d|-display\033[0m     display the plots [default: don't display]
  \033[1mclean\033[0m             clean work directory

  \033[1mall\033[0m               do everything

\033[1mPARAMETERS\033[0m
  Parameters are written in the configuration file after they are set.
  Therefore, they \"stick\" from one run to the other.
  \033[1m-diam\033[0m         40  aquarium diameter, in cm
  \033[1m-a|-angle\033[0m     90  angle between camera and compass, in degrees
  \033[1m-m|-mem\033[0m      1000 memory for Image, in MB
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
	if [[ $TEMP == "" ]]; then
		error "Temporary directory undefined"
	fi
	if [[ $data == "" ]]; then
		error "Data directory undefined"
	fi
	echoB "Committing changes"
	echo=`which echo`
	$echo -n "Do you want to commit changes? (y/n [n]) : "
	read -e COMMIT
	if [[ "$COMMIT" == "Y" || "$COMMIT" == "y" || "$COMMIT" == "yes" || "$COMMIT" == "Yes" || "$COMMIT" == "YES" ]]
	then
		echo "Moving data..."
		# we move the files to the DATA directory
		$( cd $TEMP/ && mv -i $@ $data/ )
	else
		echo "OK, cleaning TEMP directory then..."
	fi
	# clean temp directory
	rm -Rf $TEMP/*

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
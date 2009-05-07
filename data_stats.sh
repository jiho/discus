#!/bin/bash
#
#	Display some simple information regarding the availability of data per deploymnt
#
# (c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#------------------------------------------------------------------------------

# pass the working directory as command line argument
work=$1


echo -e "\n\e[1mdepl img   com gps ctd   cal trk sta\e[0m"

for i in `ls -1 $work/ | sort -n`; do
	
	# display deploy number
	echo "$i" | awk {'printf("%-5s",$1)'}
	# use awk for nice formatted output
	
	# count images
	nbImages=$(ls 2>/dev/null $work/$i/*.jpg | wc -l)
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

exit 0

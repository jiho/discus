#!/bin/sh
#
# 	BlueBidule
#
# 	Apply to some BB action to all data directories
#
#	(c) Jean-Olivier Irisson 2005-2007
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

BBFLAGS="$*"
echo "Performing actions: $BBFLAGS"

for DIR in data/0*
do
	if [ -d $DIR ]	# check that target is a directory
	then				# and perform some action on this video-id
		DIR=`basename $DIR`
		echo -e "\n\n******** Working on $DIR **********"
		./bb -id $DIR $BBFLAGS
	fi
done

#!/bin/sh
#
#	Functions useful at several stages of the analysis with DISCUS
#	- open images as a stack
#	- commit changes from the temporary directory to the data directory
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#------------------------------------------------------------------------------


open_stack()
#
#	Open images as a virtual stack
#	USAGE
#	open_stack pathToImages
#
{
	echo "Opening images as a stack ..."
	$JAVA_CMD -Xmx1000m -jar $IJ_PATH/ij.jar -ijpath $IJ_PATH/plugins/ -eval "run(\"Image Sequence...\", \"open=${1}/*.JPG number=0 starting=1 increment=1 scale=100 file=[] or=[] sort use\");"
}


commit_changes()
#
#	Ask to commit changes and copy all .txt files from TEMP to DATA
#
{
	echoB "Commiting changes"
	echo=`which echo`
	$echo -n "Do you want to commit changes? (y/n [y]) : "
	read -e COMMIT
	if [[ "$COMMIT" == "" || "$COMMIT" == "Y" || "$COMMIT" == "y" || "$COMMIT" == "yes" || "$COMMIT" == "Yes" ]]
	then
		echo "Moving data..."
		# we move the files to the DATA directory
		mv -i $TEMP/*.txt $DATA/
	else
		echo "Ok then cleaning TEMP directory..."
	fi
	# clean temp directory
	rm -f $TEMP/*.txt
}

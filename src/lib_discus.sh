#!/bin/bash
#
#	Functions useful at several stages of the analysis with DISCUS
#	- open images as a stack
#	- commit changes from the temporary directory to the data directory
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#------------------------------------------------------------------------------

commit_changes()
#
#	Ask to commit changes and copy all .txt files from TEMP to DATA
#
{
	echoB "Committing changes"
	echo=`which echo`
	$echo -n "Do you want to commit changes? (y/n [n]) : "
	read -e COMMIT
	if [[ "$COMMIT" == "Y" || "$COMMIT" == "y" || "$COMMIT" == "yes" || "$COMMIT" == "Yes" ]]
	then
		echo "Moving data..."
		# we move the files to the DATA directory
		$( cd $TEMP/ && mv -i $@ $DATA/ )
	else
		echo "Ok then cleaning TEMP directory..."
	fi
	# clean temp directory
	rm -f $TEMP/*
}

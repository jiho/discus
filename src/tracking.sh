#!/bin/bash
#
# 	BlueBidule
#
#		Launches ImageJ to perform the analysis of the tracks
#
#
#	(c) Jean-Olivier Irisson 2005-2007
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------


# Check if the stack exists if this is needed (i.e. not for the track correction steps)
if [ "$TRACK_CALIB" == "true" ] || [ "$TRACK_FIX" == "true" ] || [ "$TRACK_COMP" == "true" ] || [ "$TRACK_LARV" == "true" ]
	then
	if [ ! -e $DATA/stack.tif ]
	then
		echo -e "\033[1mERROR\033[0m I need a stack. Produce it with the \"-video\" or \"-video -t\" options"
		exit 1
	fi
	# If it exists copy it to the TEMP directory
	echo "Copying stack to working directory..."
	cp  $DATA/stack.tif $TEMP/
fi

# USEFUL FUNCTIONS
#-----------------------------------------------------------------------

open_stack()
#
#	Opens the stack
#
{
	# we open the stack with ImageJ and proceed with the tracking
	$JAVA_CMD -mx1200m -Dplugins.dir=$IJ_PATH -cp $IJ_PATH/ij.jar: ij.ImageJ $1
}

commit_changes()
#
#	Ask to commit changes and copy all .txt files from TEMP to DATA
#
{
	echo -e "\033[1mCommiting changes\033[0m"; tput sgr0
	echo "Do you want to commit changes? (y/n [y]) : "
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


# TRACKING FUNCTIONS
#-----------------------------------------------------------------------

track_calib()
#
#	Get calibration data
#
{
	echo -e "\033[1mGet calibration data\033[0m"

	# Pre-building the files to avoid typos during save process
	touch $TEMP/coord_aquarium.txt
	touch $TEMP/coord_compas.txt
	
	# extracting the first image of the stack because we only need this one
	CONVERT_CMD=`which convert`
	$CONVERT_CMD $TEMP/stack.tif[0] $TEMP/stack0.tif

	# we display the protocol
	echo -e "  \033[1mCompass\033[0m
  Use the \033[34;47m Point Selection tool \033[0m and click on the center of the compass.
  Go to \033[32mPlugins > Macros > Measure\033[0m
  Save the results to:
  $TEMP/coord_compas.txt
  (The file has already been created you just have to overwrite it)
  \033[1mAquarium\033[0m
  Select the \033[34;47m Oval Selection tool \033[0m and fit an oval on the aquarium.
  Go to \033[32mPlugins > Macros > Measure\033[0m
  Save the results to:
  $TEMP/coord_aquarium.txt

  Close the stack without saving it and quit ImageJ."

	open_stack $TEMP/stack0.tif

	commit_changes
}


track_fix()
#
#	Track the fixed point
#
{
	echo -e "\033[1mTrack the fixed point\033[0m"

	# Pre-building the files to avoid typos during save process
	touch $TEMP/track_fix.txt

	# we display the protocol
	echo -e "  Select the \033[34;47m Oval Selection tool \033[0m and fit an oval around the fixed point.
  Go to \033[32mPlugins > Threshold selection\033[0m.
  On the first frame ONLY erase any other black dots.
  Go to \033[32mPlugins > Auto Tracking\033[0m.
  Save the results to:
  $TEMP/track_fix.txt
  (The file has already been created you just have to overwrite it)

  Close the stack without saving it and quit ImageJ."

	open_stack $TEMP/stack.tif

	commit_changes
}

track_compas()
#
#	Track the compass
#
{
	echo -e "\033[1mTrack the compass\033[0m"
	# Pre-building the files to avoid typos during save process
	touch $TEMP/track_compas.txt

	# we display the protocol
	echo -e "  Select the \033[34;47m Oval Selection tool \033[0m and fit an oval on the compass.
  Keep the ALT key pressed and with an other oval (one try only) select the center of the compass.
  Go to \033[32mPlugins > Threshold selection\033[0m.
  On the first slide ONLY erase any black dot not beeing the north of the compass.
  Go to \033[32mPlugins > Auto Tracking\033[0m.
  Save the results to:
  $TEMP/track_compas.txt
  (The file has already been created you just have to overwrite it)

  Close the stack without saving it and quit ImageJ."

	open_stack $TEMP/stack.tif

	commit_changes
}


track_larva()
#
#	Track the larva
#
{
	echo -e "\033[1mTrack larva(e)\033[0m"

	# Pre-building the files to avoid typos during save process
	touch $TEMP/track_larva.txt

	# Display protocol
	echo -e "  Go to \033[32mPlugins > Manual Tracking\033[0m
  Do not care about the Time interval and Distance calibration.
  Just click \033[34;47m Add Track \033[0m and start tracking.
  The tracks end at the end of the stack or when you click \033[34;47m End Track \033[0m.
  When tracking one larvae, if it is not visible on some image(s) you can go to the next one by clicking on the \033[34;47m Right Arrow \033[0m at the bottom of the window.
  If you are not satisfied with a track just end it and DELETE it using the appropriate button of the \033[34;47m Manual Tracking \033[0m window.
  When you are done tracking click on the \033[34;47m Results \033[0m windows and \033[32mFile > Save as...\033[0m to save the tracks to:
  $TEMP/tracks_raw.txt
  (The file has already been created you just have to overwrite it)

  Close the stack without saving it and quit ImageJ."

	open_stack $TEMP/stack.tif

	commit_changes
}

tracks_correction()
#
#	Correct tracks of fixed point movement and rotation
#
{
	echo -e "\033[1mCorrect tracks\033[0m"

	# we start by checking that everything is available
	OK=0
	if [ ! -e $DATA/track_fix.txt ]
	then
		echo "Fixed point track missing, please provide it."
		OK=1
	else
		echo "Fixed point track .......OK"
	fi

	if [ ! -e $DATA/track_compas.txt ]
	then
		echo "Compass track missing, please provide it."
		OK=1
	else
		echo "Compass track track .....OK"
	fi

	if [ ! -e $DATA/track_larva.txt ]
	then
		echo "Larva(e) track(s) missing, please provide it."
		OK=1
	else
		echo "Larva(e) track(s) .......OK"
	fi

	if [ ! -e $DATA/coord_compas.txt ]
	then
		echo "Compass coordinates missing, please provide them."
		OK=1
	else
		echo "Compass coordinates .....OK"
	fi

	if [ ! -e $DATA/coord_aquarium.txt ]
	then
		echo "Aquarium coordinates missing, please provide them."
		OK=1
	else
		echo "Aquarium coordinates ....OK"
	fi

	if [ "$OK" == "1" ]
	then
		echo "Exiting..."
		exit 1
	fi

	# copy tracks into $TEMP directory
	cp $DATA/track_*.txt $TEMP/
	cp $DATA/coord_*.txt $TEMP/

	# link other useful stuff
	ln -s $RES/lib_circular_stats.R $TEMP/
	ln -s $RES/tracking.R $TEMP/
	ln -sf $DATA/stack.tif $TEMP/

	# correct larvae tracks and write output in tracks.csv
	echo "Correcting..."
	HERE=`pwd`
	cd $TEMP/
	R CMD BATCH --vanilla tracking.R
	cd $HERE

	echo -e "\033[1mCommiting changes\033[0m"; tput sgr0
	echo "Do you want to commit changes? (y/n [y]) : "
	read -e COMMIT
	if [[ "$COMMIT" == "" || "$COMMIT" == "Y" || "$COMMIT" == "y" || "$COMMIT" == "yes" || "$COMMIT" == "Yes" ]]
	then
		echo "Moving data..."
		# store data files in the DATA folder
		mv -i $TEMP/tracks.csv $DATA/
	else
		echo "Ok then cleaning TEMP directory..."
	fi
	# Clean TEMP directory
	rm -f $TEMP/track_*.txt $TEMP/coord_*.txt $TEMP/.R* $TEMP/*.R* $TEMP/*.tif
}


# ACTIONS
#-----------------------------------------------------------------------
# What is actually done is decided here
if [ "$TRACK_CALIB" == "true" ]
then
  track_calib
fi
if [ "$TRACK_FIX" == "true" ]
then
  track_fix
fi
if [ "$TRACK_COMP" == "true" ]
then
  track_compas
fi
if [ "$TRACK_LARV" == "true" ]
then
  track_larva
fi
if [ "$TRACK_CORR" == "true" ]
then
  tracks_correction
fi

# remove the stacks
rm -f $TEMP/*.tif

exit 0

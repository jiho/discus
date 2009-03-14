#!/bin/bash
#
# BlueBidule
# 
#		Enhance video, export video frame to pgm images
#
#
# (c) Jean-Olivier Irisson 2005-2007
# Released under GNU General Public Licence
# Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------


# HOUSE KEEPING
#-----------------------------------------------------------------------
# We clean a bit in case of a previous run
rm -f $LOGS/mplayer_error.txt
#touch $LOGS/mplayer_error.txt

echo $DATAREAL/video_hifi.*
# Checking the availability of a video file
if [ ! -e $DATAREAL/video_hifi.* ] && [ "$INPUT_FILE"=="" ]
	then
	echo "Error: No video file"
	exit 1
fi

# Moving video file to the data folder if it isn't there already
if [ ! -e $DATAREAL/video_hifi.* ]
	then
	# Detecting the extension of the INPUT_FILE
	INPUT_FILE_EXT=`echo "$INPUT_FILE" | awk -F . '{print $NF}'`
	echo "Copying video file..."
	cp -v "$INPUT_FILE" "$DATAREAL/video_hifi.$INPUT_FILE_EXT"
fi
INPUT_FILE_NAME=`ls $DATAREAL | grep video_hifi`
INPUT_FILE="$DATAREAL/$INPUT_FILE_NAME"


# VIDEO PROCESSING
#-----------------------------------------------------------------------
# compute the number of frames to skip based on the input and desired output framerates
VFPS=`mplayer 2>/dev/null -vo null -nosound -frames 1 $INPUT_FILE | awk	 '/VIDEO/ {print $5}'`
VFPS=`echo $VFPS | cut -d " " -f 1`
FRAMESTEP=`echo "$VFPS/$FPS" | bc`

# video parameters
CONTRASTREAL=`echo "$CONTRAST + 1" | bc`
DENOISELUMA=`echo "($DENOISE + 1) * 4" | bc`
DENOISECHROMA=`echo "($DENOISE + 1) * 3" | bc`
 
# the command line is therefore
COMMAND_LINE="-benchmark -vf framestep=$FRAMESTEP,hqdn3d=$DENOISELUMA:$DENOISECHROMA:3,eq2=1.0:$CONTRASTREAL:$BRIGHT:1.0:1.0:1.0:1.0:1.0 -nosound"
	# benchmark		speeds up mplayer when no visible video output is acutally provided
	# framestep		render only every Nth frame
	# eq2				equalizes the image. 
	# Options are: gamma:contrast:brightness:red_gamma:green_gamma:blue_gamma:weight
	# hqdn3d			denoises the image
	# nosound		disables sound (confirm that there isn't)

# check if we are in test mode or not
if [ "$TEST" == "true" ] 
then
	# only few frames of the video are converted in order to perform a test
	COMMAND_LINE="$COMMAND_LINE -frames 20"
fi

# export the frames of the video to PGM images
echo -e "\033[1mExporting video frames to PGM images\033[0m"; tput sgr0
echo "command: $COMMAND_LINE"
mplayer 1>/dev/null 2>$LOGS/mplayer_error.txt $COMMAND_LINE -vo pnm:pgm:outdir=$TEMP/pgm_images/ $INPUT_FILE


# STACKING IMAGES
#-----------------------------------------------------------------------
# ImageJ opens images as a stack, normalizes the stack and save it
echo -e "\033[1mProcessing images as a stack\033[0m"; tput sgr0
$JAVA_CMD -mx1000m -Dplugins.dir=$IJ_PATH -cp $IJ_PATH/ij.jar:$IJ_PATH RunMacro $RES/ij.macro.open_process_stack "$TEMP/pgm_images/"

# If this is a test we want to check how the stack looks
if [ "$TEST" == "true" ] 
then
	echo "$TEMP/pgm_images/stack.tif"
	echo -e "\033[1mOpening test stack\033[0m"; tput sgr0
	echo "Check if your video settings look OK and quit ImageJ"
	$JAVA_CMD -mx1000m -Dplugins.dir=$IJ_PATH -cp $IJ_PATH/ij.jar: ij.ImageJ "$TEMP/pgm_images/stack.tif"
fi


# COMMITTING
#-----------------------------------------------------------------------
# Ask the user to commit or not
echo -e "\033[1mCommiting changes\033[0m"; tput sgr0
echo "Do you want to commit changes? (y/n [y]) : "
read -e COMMIT

if [[ "$COMMIT" == "" || "$COMMIT" == "Y" || "$COMMIT" == "y" || "$COMMIT" == "yes" || "$COMMIT" == "Yes" ]]
then
	# move the files in correct data folder
	echo "Moving stack..."
	mv -i $TEMP/pgm_images/stack.tif $DATA/
		
	# saving last video parameters
	echo "Saving video parameters..."
	touch $LOGS/video_settings.txt
	mv $LOGS/video_settings.txt $TEMP
	echo "-vfps $FPS -vdenoise $DENOISE -vcontrast $CONTRAST -vbright $BRIGHT test=$TEST" | cat - $TEMP/video_settings.txt > $LOGS/video_settings.txt

	# cleaning
	rm -Rf $TEMP/pgm_images
	rm -f $TEMP/video_settings.txt

else
	echo "Ok then cleaning TEMP directory..."
	# cleaning
	rm -Rf $TEMP/*
fi

exit 0

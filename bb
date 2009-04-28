#!/bin/bash
#
# 	BlueBidule
#
#	BlueBidule (BB) is a video analysis application which allows
#	to study the orientation of swimming of coral reef fish larvae
#	enclosed in a swimming chamber.
#	For more information refer to:
#		http://rsmas.miami.edu/personal/cparis/ownfor/doc/bluebidule.html
#
#		Parses options and launches components of the video analysis
#
#
#	(c) Jean-Olivier Irisson 2005-2009
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# HELP
#-----------------------------------------------------------------------
help() {
echo -e "
\033[1mUSAGE\033[0m
  \033[1m$0 [options]\033[0m deploymentID
  Data extractaction and analysis script for the DISC.
  Options are read, in order, from built-in defaults, 
  the configuration file and the command line.

\033[1mOPTIONS\033[0m
  \033[1m-a|-all\033[0m        do everything [default: do nothing]
  \033[1m-t|-test\033[0m       simply perform a test (valid for all entries)
  \033[1m-h|-help\033[0m       display this help message
                               
  \033[1m-cal|-calib\033[0m    measure calibration data for the tracking
  \033[1m-com|-compass\033[0m  track the compass
  \033[1m-l|-larva\033[0m      track the larva(e)
  \033[1m-c|-correct\033[0m    correct the tracks
                               
  \033[1m-s|-stats\033[0m      compute statistics and plots
    \033[1m-nb|-nb-pie\033[0m  number of pie parts in the pie graph

  \033[1m-clean\033[0m         cleans work directory
   "
}


# CONFIGURATION
#-----------------------------------------------------------------------
# Source code resources path = where the source code is
HERE=`pwd`
RES="$HERE/src"

# Get library functions
source $RES/lib_shell.sh
typeset -fx echoBold
typeset -fx echoB
typeset -fx echoRed
typeset -fx echoGreen
typeset -fx echoBlue
typeset -fx warning
typeset -fx error

source $RES/lib_discus.sh
typeset -fx open_stack
typeset -fx commit_changes

# source $RES/lib_tracking.sh

# ImageJ and Java paths
JAVA_CMD=`which java`
if [[ $JAVA_CMD == "" ]]; then
	error "Java not found"
	exit 1
fi
IJ_PATH=$RES/imagej/
if [[ ! -e $IJ_PATH/ij.jar ]]; then
	error "ImageJ not found. ij.jar should be in $IJ_PATH"
	exit 1
fi

# Defaults

# ImageJ memory, in mb (should not be more than 2/3 of available physical RAM)
IJ_MEM=1000

# root folder where the folders for each deployment are
WORK=$HERE
# deployment number
VIDEOID="0"

# test switch, uses a subset of data for a smaller footprint
TEST=FALSE

# perform calibration?
TRACK_CALIB=FALSE
# track compass?
TRACK_COMP=FALSE
# track larva(e)?
TRACK_LARV=FALSE
# correct tracks?
TRACK_CORR=FALSE
# perform statistical analysis of current track?
STATS=FALSE
# clean data directory?
CLEAN=FALSE

# diameter of the aquarium, in cm
aquariumDiam=40
# number of pie parts in the pie graph
NB_PIE=20


# Getting options from the config file (overriding defaults)
for CONFIG_FILE in "bb.conf" "BlueBidule.conf"; do
	if [[ -e $CONFIG_FILE ]]; then
		source $CONFIG_FILE
	fi
done

# Getting options from the command line (overriding config file and defaults)
# until argument is null, check against known options
until [[ -z "$1" ]]; do
	case "$1" in
		-t|-test)
			TEST=TRUE
			shift 1 ;;
		-h|-help) 
			help
			exit 1 ;; 
		-cal|-calib) 
			TRACK_CALIB=TRUE
			shift 1 ;;  
		-com|-compass) 
			TRACK_COMP=TRUE
			shift 1 ;;
		-l|-larva) 
			TRACK_LARV=TRUE
			shift 1 ;;
		-c|-correct) 
			TRACK_CORR=TRUE
			shift 1 ;;
		-s|-stats) 
			STATS=TRUE
			shift 1 ;;
		-nb|-nb-pie)
			NB_PIE="$2"
			shift 2 ;;
		-a|-all) 
			TRACK_CALIB=TRUE
			TRACK_COMP=TRUE
			TRACK_LARV=TRUE
			TRACK_CORR=TRUE
			STATS=TRUE
			shift 1 ;;
		-clean) 
			CLEAN=TRUE
			shift 1 ;;      
		-*)
			error "Unknown option \"$1\" "
			help
			exit 4 ;;
		*)
			VIDEOID="$1"
			shift 1 ;;
	esac
done



# WORKSPACE
#-----------------------------------------------------------------------

# Work directory
WORK="$WORK/$VIDEOID"
if [[ ! -d $WORK ]]; then
	error "Working directory does not exist: $WORK"
	exit 1
fi

# Data directory
DATAREAL="$WORK"
# When we only perform tests, test data is saved in a subdirectory
DATATEST="$DATAREAL/test"

# Temporary directory, where all operations are done
TEMP="$WORK/tmp"
if [[ ! -e $TEMP ]]; then
	mkdir $TEMP
fi


# We export everything making it available to the rest of the process
export WORK DATA DATAREAL LOGS TEMP VIDEOID RES IJ_PATH JAVA_CMD
export TEST 
export TRACK_CALIB TRACK_COMP TRACK_LARV TRACK_CORR
export NB_PIE



# LAUNCH COMPONENTS
#-----------------------------------------------------------------------
# Test mode switches
if [[ $TEST == "TRUE" ]]; then
	warning "Test mode"
	# nb of images to read as a stack
	nbImages=10
	# use special test directory to store test results
	if [[ ! -e $DATATEST ]]; then
		mkdir $DATATEST
	fi
	DATA=$DATATEST
else
	nbImages=0
	# NB: zero means all
	# use the regular data directory
	DATA=$DATAREAL
fi


# Calibration
if [[ $TRACK_CALIB == "TRUE" ]]
then
	echoBlue "\nCALIBRATION"

	echo "Open first image for calibration"
	# Use an ImageJ macro to run everything. The macro proceeds this way
	# - Use Image Sequence to open only the first image
	# - Create a default oval
	# - use waitForUser to let the time for the user to tweak the selection
	# - measure centroid and perimeter in pixels
	# - save that to an appropriate file
	# - quit
	$JAVA_CMD -Xmx200m -jar $IJ_PATH/ij.jar -eval "     \
	run('Image Sequence...', 'open=${WORK}/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
	makeOval(402, 99, 1137, 1137);                      \
	waitForUser('Aquarium selection',                   \
		'If necessary, alter the selection to fit the aquarium better.\n \
		\nPress OK when you are done');                 \
	run('Set Measurements...', ' centroid perimeter redirect=None decimal=3'); \
	run('Measure');                                     \
	saveAs('Measurements', '${TEMP}/coord_aquarium.txt');     \
	run('Quit');"

	echo "Save aquarium coordinates"

	commit_changes
fi

# Tracking
if [[ $TRACK_LARV == "TRUE" || $TRACK_COMP == "TRUE" ]]; then

	if [[ $TRACK_LARV == "TRUE" ]]; then
		echoBlue "\nTRACKING LARVAE"
		resultFileName="larvae_track"
	elif [[ $TRACK_COMP == "TRUE" ]]; then
		echoBlue "\nTRACKING COMPASS"
		resultFileName="compass_track"

		# When manually tracking the compass, we need to have the coordinates of the center of the compass to compute the direction of rotation
		echo "Open first image for calibration"
		# Use an ImageJ macro to run everything. The macro proceeds this way
		# - use Image Sequence to open only the first image
		# - select the point selection tool
		# - use waitForUser to let the time for the user to click the compass
		# - measure centroid coordinates in pixels
		# - save that to an appropriate file
		# - quit
		$JAVA_CMD -Xmx200m -jar $IJ_PATH/ij.jar -eval "     \
		run('Image Sequence...', 'open=${WORK}/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
		setTool(7);                                         \
		waitForUser('Compass calibration',                  \
			'Please click the center of one compass.\n      \
			\nPress OK when you are done');                 \
		run('Set Measurements...', ' centroid redirect=None decimal=3'); \
		run('Measure');                                     \
		saveAs('Measurements', '${TEMP}/coord_compass.txt');\
		run('Quit');"

		echo "Save compass coordinates"
	fi

	echo "Open stack"
	# Use an ImageJ macro to run everything. The macro proceeds this way
	# - use Image Sequence to open the stack
	# - call the Manual Tracking plugin
	# - use waitForUser to let the time for the user to track larvae
	# - save the tracks to an appropriate file
	# - quit
	$JAVA_CMD -Xmx${IJ_MEM}m -jar ${IJ_PATH}/ij.jar   \
	-ijpath ${IJ_PATH}/plugins/ -eval "               \
	run('Image Sequence...', 'open=${WORK}/*.jpg number=${nbImages} starting=1 increment=1 scale=100 file=[] or=[] sort use'); \
	run('Manual Tracking');                           \
	waitForUser('Track finised?',                     \
		'Press OK when done tracking');               \
	selectWindow('Tracks');                           \
	saveAs('Text', '${TEMP}/${resultFileName}.txt');  \
	run('Quit');"

	echo "Save track"

	commit_changes
fi

# Correction
if [[ $TRACK_CORR == "TRUE" ]]
then
	echoBlue "\nCORRECTION OF TRACKS"
	# $RES/tracking.sh
fi

# Tracks analysis
if [[ $STATS == "TRUE" ]]
then
	echoBlue "\nSTATISTICAL ANALYSIS"
	# $RES/stats.sh
fi

# Cleaning
if [[ "$CLEAN" == "TRUE" ]]
then
	echoBlue "\nCLEANING DATA"
	echo "Removing test directory ..."
	rm -Rf $DATATEST
	echo "Removing temporary files ..."
	rm -Rf $TEMP
	echo "Removing logs ..."
	rm -Rf $LOGS/*
fi


echo -e "\nDone. Bye"

exit 0

#!/bin/sh
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
echo "
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
# ImageJ memory, in mb (should not be more than 2/3 of available physical RAM)
IJ_MEM=1000

# Working directory root = where the folders for each deployment are
WORK="/Users/jiho/Work/projects/ownfor/Lizard_Island/data/DISC-sorted"

# Defaults for this script options
TEST="false"

TRACK="false"
TRACK_CALIB="false"
TRACK_COMP="false"
TRACK_LARV="false"
TRACK_CORR="false"

STATS="false"
NB_PIE=20

CLEAN="false"

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
			TEST="true"
			shift 1 ;;
		-h|-help) 
			help
			exit 1 ;; 
		-cal|-calib) 
			TRACK_CALIB="true"
			shift 1 ;;  
		-com|-compass) 
			TRACK_COMP="true"
			shift 1 ;;
		-l|-larva) 
			TRACK_LARV="true"
			shift 1 ;;
		-c|-correct) 
			TRACK_CORR="true"
			shift 1 ;;
		-s|-stats) 
			STATS="true"
			shift 1 ;;
		-nb|-nb-pie)
			NB_PIE="$2"
			shift 2 ;;
		-a|-all) 
			TRACK_CALIB="true"
			TRACK_COMP="true"
			TRACK_LARV="true"
			TRACK_CORR="true"
			STATS="true"
			shift 1 ;;
		-clean) 
			CLEAN="true"
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

# select where to output data depending on the test switch
if [[ $TEST == "true" ]]; then
	if [[ ! -e $DATATEST ]]; then
		mkdir $DATATEST
	fi
	DATA=$DATATEST
else
	DATA=$DATAREAL
fi

# Temporary directory, where all operations are done
TEMP=$WORK/Temp/
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
# Test mode message
if [[ $TEST == "true" ]]
then
  warning "Test mode"
fi


# Calibration
if [[ $TRACK_CALIB == "true" ]]
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
	saveAs('Measurements', '${TEMP}/aquarium.txt');     \
	run('Quit');"

	echo "Save aquarium coordinates"

	commit_changes
fi

# Tracking
if [[ $TRACK_LARV == "true" ]]
then
	echoBlue "\nTRACKING LARVAE"

	echo "Open stack"
	# Use an ImageJ macro to run everything. The macro proceeds this way
	# - Use Image Sequence to open only the first image
	# - Create a default oval
	# - use waitForUser to let the time for the user to tweak the selection
	# - measure centroid and perimeter in pixels
	# - save that to an appropriate file
	# - quit
	$JAVA_CMD -Xmx${IJ_MEM}m -jar ${IJ_PATH}/ij.jar   \
	-ijpath ${IJ_PATH}/plugins/ -eval "               \
	run('Image Sequence...', 'open=${WORK}/*.jpg number=0 starting=1 increment=1 scale=100 file=[] or=[] sort use'); \
	run('Manual Tracking');                           \
	waitForUser('Track finised?',                     \
		'Press OK when done tracking');               \
	selectWindow('Tracks');                           \
	saveAs('Text', '${TEMP}/tracks.txt');             \
	run('Quit');"

	echo "Save track"

	commit_changes
fi

# Tracking compass
if [[ $TRACK_COMP == "true" ]]
then
	echoBlue "\nCOMPASS TRACK RECOVERY"
	# $RES/compass.sh
fi

# Correction
if [[ $TRACK_CORR == "true" ]]
then
	echoBlue "\nCORRECTION OF TRACKS"
	# $RES/tracking.sh
fi

# Tracks analysis
if [[ $STATS == "true" ]]
then
	echoBlue "\nSTATISTICAL ANALYSIS"
	# $RES/stats.sh
fi

# Cleaning
if [[ "$CLEAN" == "true" ]]
then
	echoBlue "\nCLEANING DATA"
	echo "Removing test directory ..."
	rm -Rf $DATATEST
	echo "Removing temporary files ..."
	rm -Rf $TEMP
	echo "Removing logs ..."
	rm -Rf $LOGS/*
fi


echo "\nDone. Bye"

exit 0

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
RES="$HERE/src/"

# Get library functions
source $RES/lib_shell.sh

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
WORK=$WORK/$VIDEOID/


# Data directory
DATAREAL=$WORK
# if we only perform tests, Test data is saved in a subdirectory
DATATEST=$DATAREAL/Test/

if [[ ! -e $DATATEST ]]; then
	mkdir $DATATEST
fi
# select where to output data depending on the test switch
if [[ $TEST == "true" ]]; then
	DATA=$DATATEST
else
	DATA=$DATAREAL
fi

# Temporary directory, where all operations are done
TEMP=$WORK/Temp/
if [[ ! -e $TEMP ]]; then
	mkdir $TEMP
fi

# Logs
LOGS=$WORK/Logs/
if [[ ! -e $LOGS ]]; then
	mkdir $LOGS
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
	# $RES/calib.sh
fi

# Tracking
if [[ $TRACK_LARV == "true" ]]
then
	echoBlue "\nTRACKING LARVAE"
	# $RES/tracking.sh
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

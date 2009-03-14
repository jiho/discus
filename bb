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
#	(c) Jean-Olivier Irisson 2005-2007
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# HELP
#-----------------------------------------------------------------------
help() {
echo -e "
\033[1mUSAGE\033[0m
   $0 [options] [InputFile]
Video Analysis script for BlueBidule device. Options are read
from built-in defaults, config file and command line, in this order.
\033[1mOPTIONS\033[0m
  Option       Default  Action
  \033[1m-id\033[0m          [today]  the id of the video (name...) 
  \033[1m-a|-all\033[0m      [no]     do everything [default: do nothing]
  \033[1m-t|-test\033[0m              simply perform a test (valid for all entries)
  \033[1m-h|-help\033[0m              display this help message

  \033[1m-video\033[0m                video processing only
    \033[1m-vfps\033[0m      [2]      number of frames per second
    \033[1m-vdenoise\033[0m  [0.0]    denoise factor (0.0 little, no absolute max)
    \033[1m-vcontrast\033[0m [0.0]    contrast factor (0.0 original, 1.0 maximum)
    \033[1m-vbright\033[0m   [0.0]    brightness factor (0.0 original, 1.0 maximum)

  \033[1m-tcalib\033[0m               measure calibration data for the tracking
  \033[1m-tfix\033[0m                 track the fixed point
  \033[1m-tcompas\033[0m              track the compass
  \033[1m-tlarva\033[0m               track the larva(e)
  \033[1m-tcorrect\033[0m             correct the tracks
  \033[1m-tall\033[0m                 do everything in the tracking process    

  \033[1m-stats\033[0m                compute statistics and plots
    \033[1m-nb|-nb-pie\033[0m[8]      number of pie parts in the pie graph

  \033[1m-clean\033[0m                cleans work directory
  \033[1m-p|-package\033[0m           packages work directory excluding big files
   "
}

# CONFIGURATION
#-----------------------------------------------------------------------
# Source code resources path
# = where the source code is
HERE=`pwd`
RES=$HERE/src/


# Defaults
VIDEOID=`date +"%m.%d.%y"`
TEST="false"
WORK="$HERE/data/"
# FIXME find a better way to define work directory and clean things related to WORK in bb a bit

VIDEO="false"
FPS=2
CONTRAST=0.0
DENOISE=0.0
BRIGHT=0.0

TRACK="false"
TRACK_CALIB="false"
TRACK_FIX="false"
TRACK_COMP="false"
TRACK_LARV="false"
TRACK_CORR="false"

STATS="false"
NB_PIE=20

CLEAN="false"

PACKAGE="false"

# Getting options from the config file (overriding defaults)
for CONFIG_FILE in "bb.conf" "BlueBidule.conf"
do
	if [ -f $CONFIG_FILE ]
	then
		. $CONFIG_FILE
	fi
done


# Getting options from the command line (overriding config file)
until [ -z "$1" ]		# until argument is null
do
	case "$1" in
		-id)
			VIDEOID="$2"
			shift 2 ;;
		-t|-test)
			TEST="true"
			shift 1 ;;
		-video) 
			VIDEO="true"
			shift 1 ;;
		-vfps)
			VIDEO="true"
			FPS="$2" 
			shift 2 ;;
		-vdenoise)
			VIDEO="true"
			DENOISE="$2"
			shift 2 ;;
		-vcontrast)
			VIDEO="true"
			CONTRAST="$2"
			shift 2 ;;
		-vbright)
			VIDEO="true"
			BRIGHT="$2"
			shift 2 ;;  
		-tcalib) 
			TRACK="true"
			TRACK_CALIB="true"
			shift 1 ;;  
		-tfix) 
			TRACK="true"
			TRACK_FIX="true"
			shift 1 ;;  
		-tcompas) 
			TRACK="true"
			TRACK_COMP="true"
			shift 1 ;;
		-tlarva) 
			TRACK="true"
			TRACK_LARV="true"
			shift 1 ;;
		-tcorrect) 
			TRACK="true"
			TRACK_CORR="true"
			shift 1 ;;
		-tall) 
			TRACK="true"
			TRACK_CALIB="true"
			TRACK_FIX="true"
			TRACK_COMP="true"
			TRACK_LARV="true"
			TRACK_CORR="true"
			shift 1 ;;
		-stats) 
			STATS="true"
			STATS_COMPUTE=1
			shift 1 ;;

		-nb|-nb-pie)
			NB_PIE="$2"
			shift 2 ;;
		-a|-all) 
			VIDEO="true"
			PROCESS="true"
			TRACK="true"
			TRACK_CALIB="true"
			TRACK_FIX="true"
			TRACK_COMP="true"
			TRACK_LARV="true"
			TRACK_CORR="true"
			STATS="true"
			shift 1 ;;
		-clean) 
			CLEAN="true"
			shift 1 ;;      
		-p|-package) 
			PACKAGE="true"
			shift 1 ;;      
		-h|-help) 
			help
			exit 1 ;; 
		-*)
			echo -e "\033[1mError:\033[0m Unknown Option:  \"$1\" "
			help
			exit 4 ;;
		*)
			INPUT_FILE="$1" 
			shift 1 ;;
	esac
done

# ImageJ and Java paths
IJ_PATH=$RES/imagej/
JAVA_CMD=`which java`



# WORKSPACE
#-----------------------------------------------------------------------

# Work directory
#--------------------------------------------------------
WORK=$WORK/$VIDEOID/
if [ ! -e $WORK ]
then
	echo "Creating work directory..."
	mkdir $WORK
fi

# Data directory
#--------------------------------------------------------
DATAREAL=$WORK
# if we only perform tests, Test data is saved in a subdirectory
DATATEST=$DATAREAL/Test/

# if [ ! -e $DATAREAL ]
# then
# #	echo "Creating data directory..."
# 	mkdir $DATAREAL
# fi
if [ ! -e $DATATEST ]
then
#	echo "Creating test data directory..."
	mkdir $DATATEST
fi
# Check if we are in test mode or not
if [ "$TEST" == "true" ] 
then
	DATA=$DATATEST
else
	DATA=$DATAREAL
fi

# Temporary directory, where all operations are done
#--------------------------------------------------------
TEMP=$WORK/Temp/
if [ ! -e $TEMP ]
then
#	echo "Creating temporary data directory..."
	mkdir $TEMP
fi

# Logs
#--------------------------------------------------------
LOGS=$WORK/Logs/
if [ ! -e $LOGS ]
then
#	echo "Creating logs directory..."
	mkdir $LOGS
fi


# We export everything making it available to the rest of the process
export WORK DATA DATAREAL LOGS TEMP VIDEOID RES IJ_PATH JAVA_CMD
export TEST 
export FPS SCALE CONTRAST BRIGHT DENOISE INPUT_FILE
export TRACK_CALIB TRACK_FIX TRACK_COMP TRACK_LARV TRACK_CORR
export NB_PIE



# LAUNCH COMPONENTS
#-----------------------------------------------------------------------
# Test mode message
if [ "$TEST" == "true" ]
then
  echo -e "\033[1m\033[31mTEST MODE\033[0m"; tput sgr0
fi



# Video processing
if [ "$VIDEO" == "true" ]
then
	echo -e "\n\033[1m\033[34m*** VIDEO PROCESSING ***\033[0m" ; tput sgr0
	$RES/video_process.sh
fi

# Tracking
if [ "$TRACK" == "true" ]
then
	echo -e "\n\033[1m\033[34m*** TRACKING ***\033[0m" ; tput sgr0
	$RES/tracking.sh
fi

# Tracks analysis
if [ "$STATS" == "true" ]
then
	echo -e "\n\033[1m\033[34m*** STATISTICAL ANALYSIS OF THE TRACKS ***\033[0m" ; tput sgr0
	$RES/stats.sh
fi

# Cleaning
if [ "$CLEAN" == "true" ]
then
	echo -e "\n\033[1m\033[34m*** CLEANING DATA ***\033[0m"	; tput sgr0
	echo -e "Removing test directory..."
	rm -Rf $DATATEST
	echo -e "Removing temporary files..."
	rm -Rf $TEMP
	# rm -Rf $DATAREAL/pgm_images/ 
	echo -e "Removing logs..."
	rm -Rf $LOGS/*
	# echo -e "Do you also want to remove the stack?"
	# rm -i $DATAREAL/stack.tif
fi

# Packaging
if [ "$PACKAGE" == "true"	]
then
	echo -e "\n\033[1m\033[34m*** PACKAGING DATA ***\033[0m" ; tput	sgr0
	ZIPNAME=`basename $WORK`
	zip -r $ZIPNAME.zip $ZIPNAME -x	\*.avi -x \*.mov -x	\*.tif
fi


echo "Done. Bye"


exit 0

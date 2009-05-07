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
  \033[1m$0 [options]\033[0m deployment
  Data extractaction and analysis script for the DISC.
  Deployment IDs can be specified as ranges: 1,3-5,8

\033[1mOPTIONS\033[0m
  \033[1m-t|-test\033[0m          simply perform a test
  \033[1m-h|-help\033[0m          display this help message
                                  
  \033[1m-cal|-calib\033[0m       measure calibration data for the tracking
  \033[1m-com|-compass\033[0m     track the compass manually
  \033[1m-l|-larva\033[0m         track the larva(e)
    \033[1m-sub\033[0m        1   subsample interval, in seconds
  \033[1m-c|-correct\033[0m       correct the tracks
  \033[1m-s|-stats\033[0m         compute statistics and plots
    \033[1m-ssub\033[0m       5   subsample positions every 'ssub' seconds
                    (has no effect if < to -sub above)
    \033[1m-d|-display\033[0m     display the PDF file containing the plots

  \033[1m-a|-all\033[0m           do everything [default: do nothing]
                                  
  \033[1m-clean\033[0m            clean work directory
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
typeset -fx commit_changes

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
BASE=$HERE
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

# whether to display plots or not
displayPlots=FALSE

# diameter of the aquarium, in cm
aquariumDiam=40
# subsample each 'sub' frame to speed up the analysis
sub=1
# subsample position data each 'ssub' frame to allow indpendence of data
ssub=5


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
		-d|-display)
			displayPlots=TRUE
			shift 1 ;;
		-sub)
			sub="$2"
			shift 2 ;;
		-ssub)
			ssub="$2"
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

# If VIDEOID is a range, expand it
VIDEOID=$(expand_range "$VIDEOID")

for id in $VIDEOID; do
	echoBold "\nDEPLOYMENT $id"

# Work directory
WORK="$BASE/$id"
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
export WORK DATA DATAREAL LOGS TEMP id RES IJ_PATH JAVA_CMD
export TEST 
export TRACK_CALIB TRACK_COMP TRACK_LARV TRACK_CORR



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
	run('Set Measurements...', ' centroid perimeter invert redirect=None decimal=3'); \
	run('Measure');                                     \
	saveAs('Measurements', '${TEMP}/coord_aquarium.txt');     \
	run('Quit');"

	echo "Save aquarium coordinates"

	commit_changes "coord_aquarium.txt"
fi

# Tracking
if [[ $TRACK_LARV == "TRUE" || $TRACK_COMP == "TRUE" ]]; then

	# Detect the time lapse between images
	# we use an inline R script given how easy it is to deal with time in R
	# just how cool is that!?
	interval=$(R -q --slave << EOF
		# get the time functions
		source("src/lib_image_time.R")
		# get the first x images names
		images=system("ls -1 ${WORK}/*.jpg | head -n 10", intern=TRUE)
		# compute time lapse and send it to standard output
		cat(time.lapse.interval(images))
EOF
)
# NB: for the heredoc (<< constuct) to work, there should be no tab above
	# Deduce the lag when subsampling images
	subImages=$(($sub / $interval))
	# NB: this is simple integer computaiton, so not very accurate but OK for here

	if [[ $TRACK_LARV == "TRUE" ]]; then
		echoBlue "\nTRACKING LARVAE"
		resultFileName="larvae_track.txt"
		outputFiles=$resultFileName
	elif [[ $TRACK_COMP == "TRUE" ]]; then
		echoBlue "\nTRACKING COMPASS"
		resultFileName="compass_track.txt"

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
		run('Image Sequence...', 'open=${WORK}/*.jpg number=1 starting=1 increment=${subImages} scale=100 file=[] or=[] sort'); \
		setTool(7);                                         \
		waitForUser('Compass calibration',                  \
			'Please click the center of one compass.\n      \
			\nPress OK when you are done');                 \
		run('Set Measurements...', ' centroid invert redirect=None decimal=3'); \
		run('Measure');                                     \
		saveAs('Measurements', '${TEMP}/coord_compass.txt');\
		run('Quit');"

		echo "Save compass coordinates"
		outputFiles="$resultFileName coord_compass.txt"
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
	run('Image Sequence...', 'open=${WORK}/*.jpg number=${nbImages} starting=1 increment=${subImages} scale=100 file=[] or=[] sort use'); \
	run('Manual Tracking');                           \
	waitForUser('Track finised?',                     \
		'Press OK when done tracking');               \
	selectWindow('Tracks');                           \
	saveAs('Text', '${TEMP}/${resultFileName}');  \
	run('Quit');"

	echo "Save track"

	commit_changes $outputFiles
fi

# Correction
if [[ $TRACK_CORR == "TRUE" ]]
then
	echoBlue "\nCORRECTION OF TRACKS"

	# We start by checking that everything is available and copy stuff to the temporary directory

	OK=0

	if [[ ! -e $DATA/coord_aquarium.txt ]]
	then
		error "Aquarium coordinates missing. Use:\n\t$0 -calib"
		OK=1
	else
		echo "Aquarium coordinates ....OK"
		cp $DATA/coord_aquarium.txt $TEMP
	fi

	if [[ ! -e $DATA/compass_log.csv ]]; then

		warning "Numeric compass track missing.\n  Falling back on manual compass track."

		if [[ ! -e $DATA/compass_track.txt ]]; then
			error "Manual compass track missing. Use:\n\t $0 -compass"
			OK=1
		else
			echo "Compass track ..........OK"
			cp $DATA/compass_tracks.txt $TEMP
		fi

		if [[ ! -e $DATA/coord_compass.txt ]]
		then
			error "Compass coordinates missing. Use:\n\t $0 -compass"
			OK=1
		else
			echo "Compass coordinates .....OK"
			cp $DATA/coord_compass.txt $TEMP
		fi

	else
		echo "Compass track ...........OK"
		cp $DATA/compass_log.csv $TEMP
	fi

	if [[ ! -e $DATA/larvae_track.txt ]]
	then
		error "Larva(e) track(s) missing. Use:\n\t $0 -larva"
		OK=1
	else
		echo "Larva(e) track(s) .......OK"
		cp $DATA/larvae_track.txt $TEMP
	fi


	if [[ "$OK" == "1" ]]
	then
		echo "Exiting..."
		rm -f $TEMP/*
		exit 1
	fi

	# correct larvae tracks and write output in tracks.csv
	echo "Correcting..."
	( cd $RES && R -q --slave --args ${TEMP} ${aquariumDiam} ${cameraCompassDeviation} < correct_tracks.R )
	# Test the exit status of R and proceed accordingly
	stat=$(echo $?)
	if [[ $stat != "0" ]]; then
		exit 1
	fi

	echo "Save track"

	commit_changes "tracks.csv"

fi

# Tracks analysis
if [[ $STATS == "TRUE" ]]
then
	echoBlue "\nSTATISTICAL ANALYSIS"

	# Checking for tracks existence and copy the tracks in the TEMP directory
	if [[ -e $DATA/tracks.csv ]]; then
		echo "Corrected track(s) .......OK"
		cp $DATA/tracks.csv $TEMP/
	else
		error "Corrected tracks missing. Use:\n\t $0 -correct"
		exit 1
	fi

	(cd $RES && R -q --slave --args ${TEMP} ${aquariumDiam} ${ssub} < stats.R)
	# Test the exit status of R and proceed accordingly
	stat=$(echo $?)
	if [[ $stat != "0" ]]; then
		exit 1
	fi

	# Display the plots in a PDF reader
	if [[ $displayPlots == "TRUE" ]]; then
		pdfReader=""
		if [[ $(uname) == "Darwin" ]]; then
			# on Mac OS X use "open" to open wih the default app associated with PDFs
			pdfReader=open
		else
			# on linux, try to find some common pdf readers
			if [[ $(which evince) != "" ]]; then
				pdfReader=evince
			elif [[ $(which xpdf) != "" ]]; then
				pdfReader=xpdf
			else
				warning "Could not find a pdf reader, do not use option -display"
			fi
		fi
		if [[ pdfReader != "" ]]; then
			$pdfReader &>/dev/null $TEMP/plots*.pdf
		fi
	fi

	echo "Save statistics and graphics"

	commit_changes "stats.csv" plots*.pdf
fi

# Cleaning
if [[ $CLEAN == "TRUE" ]]
then
	echoBlue "\nCLEANING DATA"
	echo "Removing test directory ..."
	rm -Rf $DATATEST
	echo "Removing temporary files ..."
	rm -Rf $TEMP
fi

done


echo -e "\nDone. Bye"

exit 0

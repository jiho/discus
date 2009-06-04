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
  \033[1m$0 [options]\033[0m action[s] deployment
  Data extraction and analysis script for the DISC.
  Actions perform a data analysis step and are whole or abbreviated words.
  Options modify the behaviour of the script and are prepended a \"-\" sign.
  Deployment numbers can be specified as ranges: 1,3-5,8

\033[1mACTIONS / relevant OPTIONS\033[0m
  \033[1mh|help\033[0m            display this help message

  \033[1m-t|-test\033[0m          simply perform a test

  \033[1mcal|calib\033[0m         measure calibration data for the tracking

  \033[1mcom|compass\033[0m       track the compass manually
  \033[1ml|larva\033[0m           track the larva(e)
    \033[1m-sub\033[0m        1   subsample interval, in seconds

  \033[1mc|correct\033[0m         correct the tracks
    \033[1m-diam\033[0m       40  aquarium diameter, in cm
    \033[1m-a|-angle\033[0m   90  angle between camera and compass in degrees
          \033[1mNB\033[0m both options are written in the configuration file
             therefore, they \"stick\" from one run to the other

  \033[1ms|stats\033[0m           compute statistics and plots
    \033[1m-psub\033[0m       5   subsample positions every 'psub' seconds
                    (has no effect when < to -sub above)
    \033[1m-d|-display\033[0m     display the plots [default: don't display]

  \033[1mclean\033[0m             clean work directory

  \033[1mall\033[0m               do everything

  \033[1mstatus\033[0m            prints information about the data directory
   "
}

# detect whether we just want the help (this overrides all the other options and we want it here to avoid dealing with the config file etc when the user just wants to read the help)
echo $* | grep -E -e "h|help" > /dev/null
if [[ $? == "0" ]]; then
	help
	exit 0
fi

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
typeset -fx read_config
typeset -fx write_pref

source $RES/lib_discus.sh
typeset -fx commit_changes
typeset -fx data_status

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

# Parameters: only set here
# ImageJ memory, in mb (should not be more than 2/3 of available physical RAM)
IJ_MEM=500
# aquarium boundary coordinates
aquariumBounds="10,10,300,300"


# Actions: determined on the command line, all FALSE by default
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


# Options: set in the config file or on the command line
# test switch, uses a subset of data for a smaller footprint
TEST=FALSE

# root directory where the directories for each deployment are
base=$HERE
# deployment number (i.e. deployment directory name)
deployNb="0"

# diameter of the aquarium, in cm
aquariumDiam=40
# subsample images every 'sub' seconds to speed up the analysis
sub=1
# subsample positions each 'psub' seconds for the statistical analysis, to allow independence of data
psub=5
# whether to display plots or not after the statistical analysis
displayPlots=FALSE
# angle between the top of the picture and the forward direction of the compass
cameraCompassAngle=90


# Getting options from the config file (overriding defaults)
CONFIG_FILE="bb.conf"
if [[ -e $CONFIG_FILE ]]; then
	read_config $CONFIG_FILE
fi

# Getting options from the command line (overriding config file and defaults)
# until argument is null, check against known options
until [[ -z "$1" ]]; do
	case "$1" in
		h|help)
			help
			exit 0 ;;
		status)
			data_status $base
			exit $? ;;
		cal|calib)
			TRACK_CALIB=TRUE
			shift 1 ;;
		com|compass)
			TRACK_COMP=TRUE
			shift 1 ;;
		l|larva)
			TRACK_LARV=TRUE
			shift 1 ;;
		c|correct)
			TRACK_CORR=TRUE
			shift 1 ;;
		s|stats)
			STATS=TRUE
			shift 1 ;;
		clean)
			CLEAN=TRUE
			shift 1 ;;
		all)
			TRACK_CALIB=TRUE
			TRACK_COMP=TRUE
			TRACK_LARV=TRUE
			TRACK_CORR=TRUE
			STATS=TRUE
			CLEAN=TRUE
			shift 1 ;;
		-t|-test)
			TEST=TRUE
			shift 1 ;;
		-d|-display)
			displayPlots=TRUE
			shift 1 ;;
		-sub)
			sub="$2"
			shift 2 ;;
		-psub)
			psub="$2"
			shift 2 ;;
		-diam)
			aquariumDiam="$2"
			write_pref $CONFIG_FILE aquariumDiam
			shift 2 ;;
		-a|-angle)
			cameraCompassAngle="$2"
			write_pref $CONFIG_FILE cameraCompassAngle
			shift 2 ;;
		-*)
			error "Unknown option \"$1\" "
			help
			exit 4 ;;
		*)
			deployNb="$1"
			shift 1 ;;
	esac
done



# DATAREALSPACE
#-----------------------------------------------------------------------

# If deployNb is a range, expand it
deployNb=$(expand_range "$deployNb")

for id in $deployNb; do
	echoBold "\nDEPLOYMENT $id"

# Work directory
DATAREAL="$base/$id"
if [[ ! -d $DATAREAL ]]; then
	error "DATA directory does not exist:\n  $DATAREAL"
	exit 1
fi

# When we only perform tests, test data is saved in a subdirectory
DATATEST="$DATAREAL/test"

# Temporary directory, where all operations are done
TEMP="$DATAREAL/tmp"
if [[ ! -e $TEMP ]]; then
	mkdir $TEMP
fi



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
	# - use Image Sequence to open only the first image
	# - create a default oval
	# - use waitForUser to let the time for the user to tweak the selection
	# - measure centroid and perimeter in pixels
	# - save that to an appropriate file
	# - quit
	$JAVA_CMD -Xmx200m -jar $IJ_PATH/ij.jar -eval "     \
	run('Image Sequence...', 'open=${DATAREAL}/pics/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
	makeOval(${aquariumBounds});                        \
	waitForUser('Aquarium selection',                   \
		'If necessary, alter the selection to fit the aquarium better.\n \
		\nPress OK when you are done');                 \
	run('Set Measurements...', '  centroid perimeter invert redirect=None decimal=3'); \
	run('Measure');                                     \
	saveAs('Measurements', '${TEMP}/coord_aquarium.txt');     \
	run('Clear Results');                               \
	run('Set Measurements...', '  bounding redirect=None decimal=3'); \
	run('Measure');                                     \
	saveAs('Measurements', '${TEMP}/bounding_aquarium.txt');     \
	run('Quit');"

	# save the bounding rectangle measurements in the configuration file
	aquariumBounds=$(sed \1d ${TEMP}/bounding_aquarium.txt | awk -F " " {'print $2","$3","$4","$5'})

	write_pref $CONFIG_FILE aquariumBounds

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
		images=system("ls -1 ${DATAREAL}/pics/*.jpg | head -n 10", intern=TRUE)
		# compute time lapse and send it to standard output
		cat(time.lapse.interval(images))
EOF
)
# NB: for the heredoc (<< constuct) to work, there should be no tab above
	# Deduce the lag when subsampling images
	subImages=$(($sub / $interval))
	# NB: this is simple integer computation, so not very accurate but OK for here
	# when $sub is smaller than $interval (i.e. subImages <1 and in that case =0 since we are doing integer computation) it means we want all images. So subImages should be 1
	if [[ $subImages -eq 0 ]]; then
	        subImages=1
	fi

	# Determine whether to use a virtual stack or a real one
	# total number of images
	allImages=$(ls -1 ${DATAREAL}/pics/*.jpg | wc -l)
	# nb of images opened = total / interval
	nbFrames=$(($allImages / $subImages))
	# when there are less than 100 frames, loading them is fast and not too memory hungry
	if [[ $nbFrames -le 100 ]]; then
		virtualStack=""
	else
		virtualStack="use"
	fi

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
		run('Image Sequence...', 'open=${DATAREAL}/pics/*.jpg number=1 starting=1 increment=${subImages} scale=100 file=[] or=[] sort'); \
		setTool(7);                                         \
		waitForUser('Compass calibration',                  \
			'Please click the center of the compass you intend to track.\n      \
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
	run('Image Sequence...', 'open=${DATAREAL}/pics/*.jpg number=${nbImages} starting=1 increment=${subImages} scale=100 file=[] or=[] sort ${virtualStack}'); \
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
			cp $DATA/compass_track.txt $TEMP
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
	( cd $RES && R -q --slave --args ${TEMP} ${aquariumDiam} ${cameraCompassAngle} < correct_tracks.R )
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

	(cd $RES && R -q --slave --args ${TEMP} ${aquariumDiam} ${psub} < stats.R)
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

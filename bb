#!/bin/bash
#
#  DISCUS
#
#  Drifting In-Situ Chamber User Software
#
#  DISCUS is a set of scripts which allow the extraction and
#  analysis of data collected with the DISC to study the
#  orientation of marine larvae in situ.
#
#  For more information about the research, search for papers by
#  Claire Paris, Cedric Guigand and Jean-Olivier Irisson
#  For more information about the software, please see the 'doc'
#  directory directly next to this file.
#
#  This file parses options and launches the different components
#
#  (c) Copyright 2005-2011 J-O Irisson, C Paris
#  GNU General Public License
#  Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# Give a bit of room
echo ""



# SOURCE
#-----------------------------------------------------------------------

# set directories where the source code is
HERE=$(pwd)
RES="$HERE/src"

# get library functions
source $RES/lib_shell.sh
typeset -fx echoBold
typeset -fx echoB
typeset -fx echoRed
typeset -fx echoGreen
typeset -fx echoBlue
typeset -fx warning
typeset -fx error
typeset -fx status
typeset -fx dereference
typeset -fx expand_range
typeset -fx yes

source $RES/lib_discus.sh
typeset -fx help
typeset -fx commit_changes
typeset -fx data_status
typeset -fx sync_data
typeset -fx read_config
typeset -fx write_pref


# When asked, display the help message immediately and then exit
# Therefore it overrides all the other options, so we want it early in the process to avoid dealing with the config file etc. when the user just wants to read the help
# detect whether the command line contains the words "h" or "help"
echo $* | grep -E -e "\b(h|help)\b" > /dev/null
if [[ $? -eq 0 ]]; then
	help
	exit $?
fi



# CONFIGURATION
#-----------------------------------------------------------------------

# Set defaults

# Parameters: stick from one deployment to the next because they are copied in the config file
# ImageJ memory, in mb (should not be more than 2/3 of available physical RAM)
mem=1000
# aquarium boundary coordinates (top, left, width, height)
aquariumBounds="10,10,300,300"
# angle between the top of the picture and the forward direction of the compass
angle=90
# diameter of the aquarium, in cm
diam=40
# working directory containing directories for all deployments (workspace)
work=$HERE
# storage directory containing directories for all deployments (data source and backup)
storage=""

# Actions: determined on the command line, all FALSE by default
# perform any action
ACT=FALSE
# get images from video
VIDEO=FALSE
# stabilize images
STAB=FALSE
# perform calibration
CALIB=FALSE
# track compass
TRACK_COMP=FALSE
# track larva(e)
TRACK_LARV=FALSE
# correct tracks
CORR=FALSE
# perform statistical analysis of current deployment
STATS=FALSE
# get data from the storage directory
GET=FALSE
# store data to the storage directory
STORE=FALSE
# give information about the content of the data or storage directory
STATUS=FALSE

# Options: set in the config file or on the command line, for each run, alter the behaviour of actions
# deployment number (i.e. deployment directory name)
deployNb=""
# subsample images every 'sub' seconds to speed up the analysis
sub=1
# subsample positions every 'psub' seconds for the statistical analysis, to make positions independent
psub=5
# rounding (=binning) for measured angles, in degrees
binangle=0
# whether to display plots or not after the statistical analysis
display=FALSE
# display the storage directory status rather than the data directory status for the STATUS action
s=FALSE
# whether the camera is looking up at the arena
lookingUp=FALSE
# assume yes at every question (move data, overwrite data etc.)
yes=FALSE


# Get options from the config file (overriding defaults)
configFile="bb.conf"
if [[ -e $configFile ]]; then
	read_config $configFile
	status $? "Cannot read configuration file"
fi


# Get options from the command line (overriding config file and defaults)
# until argument is null, check against known options
until [[ -z "$1" ]]; do
	case "$1" in
		h|help)
			help
			exit $? ;;
		status)
			STATUS=TRUE
			shift 1 ;;
		-s)
			s=TRUE
			shift 1 ;;
		v|video)
			VIDEO=TRUE
			ACT=TRUE
			shift 1 ;;
		stab)
			STAB=TRUE
			ACT=TRUE
			shift 1 ;;
		cal|calib)
			CALIB=TRUE
			ACT=TRUE
			shift 1 ;;
		com|compass)
			TRACK_COMP=TRUE
			ACT=TRUE
			shift 1 ;;
		l|larva)
			TRACK_LARV=TRUE
			ACT=TRUE
			shift 1 ;;
		c|correct)
			CORR=TRUE
			ACT=TRUE
			shift 1 ;;
		s|stats)
			STATS=TRUE
			ACT=TRUE
			shift 1 ;;
		get)
			GET=TRUE
			ACT=TRUE
			shift 1 ;;
		store)
			STORE=TRUE
			ACT=TRUE
			shift 1 ;;
		all)
			CALIB=TRUE
			TRACK_LARV=TRUE
			CORR=TRUE
			STATS=TRUE
			ACT=TRUE
			shift 1 ;;
		-d|-display)
			display=TRUE
			shift 1 ;;
		-sub)
			sub="$2"
			shift 2 ;;
		-psub)
			psub="$2"
			shift 2 ;;
		-bin)
			binangle="$2"
			shift 2 ;;
		-yes)
			yes=TRUE
			shift 1;;
		-diam)
			diam="$2"
			write_pref $configFile diam
			# diam is a parameter, so it is saved in the configuration file with write_pref
			# when the parameter already exists in the config file, write pref only updates it
			# see lib_discus.sh for details
			shift 2 ;;
		-a|-angle)
			angle="$2"
			write_pref $configFile angle
			shift 2 ;;
		-m|-mem)
			mem="$2"
			write_pref $configFile mem
			shift 2 ;;
		-storage)
			storage="$2"
			write_pref $configFile storage
			shift 2 ;;
		-work)
			work="$2"
			write_pref $configFile work
			shift 2 ;;
		-*)
			error "Unknown option \"$1\" "
			help
			exit 4 ;;
		*)
			deployNb="$1"
			# deployNb contains the full, un-interpreted string of deployment numbers
			# i.e. possibly a range specification such as 1,3-4,7
			shift 1 ;;
	esac
done



# CHECKS
#------------------------------------------------------------

# Existence of commands

# java is necessary for ImageJ
javaCmd=$(which java)
status $? "Java not found. Please install a Java JRE"

# test if ImageJ is installed
ijPath=$RES/imagej/
if [[ ! -e $ijPath/ij.jar ]]; then
	warning "ImageJ not found, trying to download it"
	curl http://rsb.info.nih.gov/ij/upgrade/ij.jar > $ijPath/ij.jar
	status $? "Cannot download ImageJ.\nPlease manually download the platform independent file from\n  http://rsbweb.nih.gov/ij/download.html\nand place ij.jar in $ijPath"
fi

# R is used for the correction and statistics
R=$(which R)
status $? "R not found. Please install it,\ntogether with packages ggplot2 and circular."

# rsync is used to move data back and forth between working and storage directories
rsync=$(which rsync)
status $? "rsync not found. Check your PATH."

# exiftool is used to read the metadata (time, exposure, etc...) in pictures
exiftool=$(which exiftool)
status $? "exiftool not found. Please install it\nhttp://www.sno.phy.queensu.ca/~phil/exiftool/"


# Compatibility of arguments
# If we want the get or store dat in the storage directory but that it is undefined, exit
if [[ ( $GET == "TRUE" || $STORE == "TRUE" ) && $storage == "" ]]; then
	error "Exchange of data with storage requested\n  but no storage directory specified\n  please use the -storage parameter"
	exit 1
fi

# If we want the status of the storage directory but that it is undefined, exit
if [[ $STATUS == "TRUE" && $s == "TRUE" && $storage == "" ]]; then
	error "Status of the storage directory requested but no storage directory specified\n  please use the -storage parameter"
	exit 1
fi

# If we need the storage directory for anything and that it does not exist, exit
if [[ ( ( $GET == "TRUE" || $STORE == "TRUE" ) || ( $STATUS == "TRUE" && $s == "TRUE" ) ) && ! -d $storage ]]; then
	error "Storage directory\n  $storage\n  does not exist"
	exit 1
fi



# STATUS
#------------------------------------------------------------
# If status is requested, print it now and then exit
# This discards the rest of the actions possibly on the command line
if [[ $STATUS == "TRUE" ]]; then
	echoBlue "DATA SUMMARY"
	if [[ $s == "TRUE" ]]; then
		echo "for $storage"
		data_status $storage
	else
		echo "for $work"
		data_status $work
	fi

	exit 0
fi



# PROCESS DEPLOYMENTS
#------------------------------------------------------------
# if deployNb is a range, expand it to a list of single deployments
#  i.e.   1-4,7   becomes    1 2 3 4 7
deployNb=$(expand_range "$deployNb")
status $? "Could not interpret deployment number"
# if deployNb is not specified, process all available deployments
if [[ $deployNb == "" && $ACT == "TRUE" ]]; then
	warning "No deployment number specified.\nIterating command(s) on all available deployments"
	deployNb=$(ls $work | sort -n)
fi

# Test wether we need to do anything. If not just exit
if [[ $ACT == "TRUE"  ]]; then

# If yes, loop on all specified deployments
for id in $deployNb; do

	# PREPARE WORKSPACE
	#-----------------------------------------------------------------------

	echoBold "\nDEPLOYMENT $id"

	# Define current deployment directory
	data="$work/$id"

	# If requested, first get it from the storage
	# (we need to do that first, before trying to access the data)
	if [[ $GET == "TRUE" ]]; then
		echoBlue "\nDATA IMPORT"
		# see lib_discus for the details of the function sync_data
		sync_data $work $storage get $id
		status $? "Check command line arguments"
	fi
	# otherwise test its existence
	if [[ ! -d $data ]]; then
		error "Deployment directory does not exist:\n  $data"
		continue
	fi

	# Define the source of images (pictures or video)
	pics="$data/pics"
	videoFile="$data/video_hifi.mov"
	# If the VIDEO action is specified, test for the existence of the video file
	if [[ $VIDEO == "TRUE" && ! -e $videoFile ]]; then
		error "Cannot find video file:\n  $pics"
		continue

	# Else, if any action requiring access to the pictures is specified, test for their presence
	elif [[ ( $STAB == "TRUE" || $CALIB == "TRUE" || $TRACK_LARV == "TRUE" || $TRACK_COMP == "TRUE" ) && ! -d $pics ]]; then
		error "Cannot find pictures directory:\n  $pics"
		continue
	fi

	# Define and create temporary directory, where all operations are done
	tmp="$data/tmp"
	if [[ ! -e $tmp ]]; then
		mkdir $tmp
		status $? "Could not create temporary directory"
	fi


	# LAUNCH ACTIONS
	#-----------------------------------------------------------------------

	# Video processing into individual files
	if [[ $VIDEO == "TRUE" ]]
	then
		echoBlue "\nVIDEO PROCESSING"

		# tests for the eavailability of MPlayer
		mplayer=$(which mplayer)
		status $? "mplayer not found. Please install it."

		# get the frame rate of the video
		videoFPS=$($mplayer 2>/dev/null -vo null -nosound -frames 1 $videoFile | awk '/VIDEO/ {print $5}')
		videoFPS=$(echo $videoFPS | cut -d " " -f 1)
		# compute the step size (a nb of frames) corresponding to the subsampling parameter
		frameStep=$(echo "$videoFPS * $sub" | bc -l)
		# round the number (it is a number of frames so it needs to be an integer)
		frameStep=$(echo "scale=0;($frameStep+0.5)/ 1" | bc -l)
		# the rounding above means that images are not exactly 'sub' seconds apart
		# recompute the real subsample interval
		exactSub=$(echo "$frameStep/$videoFPS" | bc -l)

		# set up MPlayer's options
		mplayerOptions="-nolirc -benchmark -vf framestep=$frameStep -nosound -vo jpeg:quality=90:outdir=$tmp/pics"
		# -nolirc       don't try to find infra-red support (avoids messages on stdout)
		# -benchmark    speeds up mplayer when no visible video output is actually provided
		# -vf           video filter
		#  framestep    render only every Nth frame
		# -nosound      disables sound (speedup?)
		# -vo           video output
		#  jpeg:outdir  to jpeg files in directory outdir

		# use MPLayer to export the frames of the video to JPEG images
		echo "Export video frames every $(printf "%1.6s" $exactSub) seconds"
		$mplayer 1>/dev/null $mplayerOptions $videoFile

		# rename output files as 1.jpg, 2.jpg etc. (so that they are handled correctly in R afterwards)
		# = suppress the zeros
		for img in $(ls $tmp/pics); do
			mv $tmp/pics/$img $tmp/pics/${img//0/}
		done

		# Set time in the EXIF properties of the images
		# The image time is used in the following to compute statistical subsampling, swimming speeds, etc.
		echo "Set time stamps on exported images"
		# Use R inline because it is easier to deal with dates
		dummy=$(R --slave << EOF
			# set an arbitrary initial date and time
			initialDate = as.POSIXct(strptime("1900:01:01 00:00:00", format="%Y:%m:%d %H:%M:%S"))
			# get the pictures names
			pics = system("ls -1 ${tmp}/pics | sort -n", intern=TRUE)
			# create an artificial sequence of dates with the correct interval
			options("digits.secs" = 2)
			dates = seq(initialDate, length.out=length(pics), by=${exactSub})
			# assign a date to each image using exiftool
			for ( i in seq(along=pics)) {
				date = format(dates[i], "%Y:%m:%d %H:%M:%S")
				subsec = substr(format(dates[i], "%OS"),4,5)
				system(paste("exiftool -overwrite_original -CreateDate='",date,"' -SubsecTime='",subsec,"' ${tmp}/pics/",pics[i],sep=""))
			}
EOF
)
		status $? "R exited abnormally"

		echo "Save exported images"
		# move data from the temporary directory to the deployment directory
		# see lib_discus.sh
		commit_changes pics

	fi

	# Image stabilization
	if [[ $STAB == "TRUE" ]]; then
		echo "Stabilize images"
		# Use ImageJ to
		# - open images as a stack
		# - stabilize the stack with the Image Stabilizer plugin
		# - export back the slices as JPEG images
		# We do all that in batch mode, without user interaction so the macro code needs to be in a separate file: Run_Image_Stabilizer.ijm
		$javaCmd -jar $ijPath/ij.jar -ijpath $ijPath -batch $ijPath/macros/Run_Image_Stabilizer.ijm $data > /dev/null 2>&1

		status $? "ImageJ exited abnormally"

		echo "Copy images metadata"
		# ImageJ discards the EXIF metadata when exporting images form the stack
		# We need still need time stamps for the following so we copy them from the orignal images to the ones exported by Image J
		for img in $(ls $data/pics); do
			# Copy all metadata from the original image in $data
			# -P	except the modification date (use current time)
			# -q	be quiet
			$exiftool -P -q -overwrite_original -TagsFromFile $data/pics/$img -all:all $tmp/pics/$img
		done

		# Here we need to explicitly overwrite the previous images directory
		# so we give an appropriate message
		echo "Overwrite original images with stabilized ones"
		commit_changes pics

	fi

	# Calibration
	if [[ $CALIB == "TRUE" ]]
	then
		echoBlue "\nCALIBRATION"

		echo "Open first image for calibration"
		# Use an ImageJ macro, inline, to run everything. The macro proceeds this way
		# - use Image Sequence to open only the first image
		# - create a default oval
		# - use waitForUser to let the time for the user to tweak the selection
		# - measure centroid and perimeter in pixels
		# - save that to an appropriate file
		# - quit
		$javaCmd -Xmx200m -jar $ijPath/ij.jar               \
		-ijpath $ijPath -eval "                             \
		run('Image Sequence...', 'open=${pics}/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
		makeOval(${aquariumBounds});                        \
		waitForUser('Aquarium selection',                   \
			'If necessary, alter the selection to fit the aquarium better.\n               \
			\nPress OK when you are done');                  \
		run('Set Measurements...', '  centroid perimeter invert redirect=None decimal=3'); \
		run('Measure');                                     \
		saveAs('Measurements', '${tmp}/coord_aquarium.txt');\
		run('Clear Results');                               \
		run('Set Measurements...', '  bounding redirect=None decimal=3'); \
		run('Measure');                                     \
		saveAs('Measurements', '${tmp}/bounding_aquarium.txt');           \
		run('Quit');"  > /dev/null 2>&1

		status $? "ImageJ exited abnormally"

		if [[ -e "${tmp}/bounding_aquarium.txt" ]]; then
			# save the bounding rectangle measurements in the configuration file
			# these will be used in future runs to position the circle where is was before
			# since the aquarium does not move much from one deployment to the next, it allows to set it only one time
			aquariumBounds=$(sed \1d ${tmp}/bounding_aquarium.txt | awk -F " " {'print $2","$3","$4","$5'})

			write_pref $configFile aquariumBounds
		else
			warning "Cannot save bounding box of the aquarium"
		fi

		echo "Save aquarium radius"

		commit_changes "coord_aquarium.txt"
	fi

	# Manual tracking function used to track the larva or the compass
	# It has to be local (i.e. defined here rather than in a separate file) because it currently references many global variables
	function manual_track ()
	#
	# Track objects manually
	#
	{
		# All arguments given on the command line are names of files to save
		outputFiles=$@
		# The result of the tracking is saved in the first one
		resultFileName=$1

		# Detect the time lapse between images, in seconds
		# we use an inline R script given how easy it is to deal with time in R
		interval=$(R -q --slave << EOF
			# get the time functions
			source("src/lib_image_time.R")
			# get the first 10 images names
			images=system("ls -1 ${pics}/*.jpg | head -n 10", intern=TRUE)
			# compute mean time lapse between images and send it to standard output
			cat(time.lapse.interval(images))
EOF
)
# NB: for the heredoc (<< construct) to work, the lines above should not be indented
		status $? "R exited abnormally"

		# From the interval between images and the $sub parameters (both in seconds)
		# deduce the lag (in number of images) to use when subsampling images
		subImages=$(($sub / $interval))
		# NB: this is simple integer computation, so not very accurate but OK for here
		# when $sub is smaller than $interval, then subImages < 1 (i.e. = 0 here because we are doing integer computation).
		# It means we want all images, so subImages should in fact be 1
		if [[ $subImages -eq 0 ]]; then
			subImages=1
		fi

		# Determine whether to use a virtual stack or a real one
		# total number of images
		allImages=$(ls -1 ${pics}/*.jpg | wc -l)
		# nb of images opened = total / interval
		nbFrames=$(($allImages / $subImages))
		# when there are less than 100 frames to open, loading them is fast and not too memory hungry
		# in that case, use a regular stack, other wise use a virtual stack
		if [[ $nbFrames -le 30 ]]; then
			virtualStack=""
		else
			virtualStack="use"
		fi

		echo "Open stack"
		# Use an ImageJ macro to run everything. The macro proceeds this way
		# - use Image Sequence to open the stack
		# - call the Manual Tracking plugin
		# - use waitForUser to let the time for the user to track larvae
		# - save the tracks to an appropriate file
		# - quit
		$javaCmd -Xmx${mem}m -jar ${ijPath}/ij.jar        \
		 -ijpath $ijPath -eval "                          \
		run('Image Sequence...', 'open=${pics}/*.jpg number=0 starting=1 increment=${subImages} scale=100 file=[] or=[] sort ${virtualStack}'); \
		run('Manual Tracking');                           \
		waitForUser('Track finished?',                    \
		    'Press OK when done tracking');               \
		selectWindow('Tracks');                           \
		saveAs('Text', '${tmp}/${resultFileName}');       \
		run('Quit');"  > /dev/null 2>&1

		status $? "ImageJ exited abnormally"

		echo "Save track"

		commit_changes $outputFiles
	}

	# Track compass
	if [[ $TRACK_COMP == "TRUE" ]]; then
		echoBlue "\nTRACKING COMPASS"

		# When manually tracking the compass, we need to have the coordinates of the center of the compass to compute the direction of rotation
		echo "Open first image for calibration"
		# Use an ImageJ macro to run everything. The macro proceeds this way
		# - use Image Sequence to open only the first image
		# - select the point selection tool
		# - use waitForUser to let the time for the user to click the compass
		# - measure centroid coordinates in pixels
		# - save that to an appropriate file
		# - quit
		$javaCmd -Xmx200m -jar $ijPath/ij.jar               \
		-ijpath $ijPath -eval "                             \
		run('Image Sequence...', 'open=${pics}/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
		setTool(7);                                         \
		waitForUser('Compass calibration',                  \
			'Please click the center of the compass you intend to track.\n      \
			\nPress OK when you are done');                  \
		run('Set Measurements...', ' centroid invert redirect=None decimal=3'); \
		run('Measure');                                     \
		saveAs('Measurements', '${tmp}/coord_compass.txt'); \
		run('Quit');"  > /dev/null 2>&1

		status $? "ImageJ exited abnormally"

		# Call the manual tracking routine
		manual_track compass_track.txt coord_compass.txt
	fi

	# Track larvae
	if [[ $TRACK_LARV == "TRUE" ]]; then
		echoBlue "\nTRACKING LARVAE"
		# just call the manual tracking routine
		manual_track larvae_track.txt
	fi

	# Correction
	if [[ $CORR == "TRUE" ]]
	then
		echoBlue "\nCORRECTION OF TRACKS"

		# We start by checking that every piece of data needed for the correction is available
		# and we copy them to the temporary directory

		OK="TRUE"

		if [[ ! -e $data/coord_aquarium.txt ]]
		then
			error "Aquarium coordinates missing. Use:\n\t$0 calib $id"
			OK="FALSE"
		else
			echo "Aquarium coordinates ....OK"
			cp $data/coord_aquarium.txt $tmp
		fi

		if [[ ! -e $data/compass_log.csv ]]; then

			warning "Numeric compass track missing.\n\t Trying to fetch manual compass track."

			if [[ ! -e $data/compass_track.txt || ! -e $data/coord_compass.txt ]]; then
				warning "Manual compass track or compass coordinates missing.\n\t No correction applied.\n\t Use: \`$0 compass $id\` to track the compass if need be."
			else
				echo "Compass track ...........OK"
				cp $data/compass_track.txt $tmp
				cp $data/coord_compass.txt $tmp
				compass="manual"
			fi

		else
			echo "Compass track ...........OK"
			cp $data/compass_log.csv $tmp
			compass="auto"
		fi

		if [[ ! -e $data/larvae_track.txt ]]
		then
			error "Larva(e) track(s) missing. Use:\n\t $0 larva $id"
			OK="FALSE"
		else
			echo "Larva(e) track(s) .......OK"
			cp $data/larvae_track.txt $tmp
		fi


		if [[ "$OK" == "FALSE" ]]
		then
		# Something is missing, just exit
			echo "Exiting..."
			rm -f $tmp/*
			continue
		fi

		# When the manual compass is used, we do not have roll information to detect whether the camera is above or below the aquarium and we need to collect input from the user
		if [[ $compass == "manual" ]]; then
			echo "Which was the configuration of the instrument:"
			PS3="? "
			select choice in "the camera was ABOVE the arena" "the camera was BELOW the arena"
			do
				if [[ $REPLY == 1 ]]; then
					echo "OK, ($REPLY) the camera was above, looking down on the arena."
					lookingUp=FALSE
					break
				elif [[ $REPLY == 2 ]]; then
					echo "OK, ($REPLY) the camera was below, looking up at the arena."
					lookingUp=TRUE
					break
				else
					PS3="Not a valid choice, please choose 1 or 2 : "
				fi
			done
		fi

		# correct larvae tracks and write output in tracks.csv
		echo "Correcting..."
		( cd $RES && R -q --slave --args ${tmp} ${diam} ${angle} ${lookingUp} < correct_tracks.R )

		status $? "R exited abnormally"

		echo "Save track"
		commit_changes "tracks.csv"

	fi

	# Tracks analysis
	if [[ $STATS == "TRUE" ]]
	then
		echoBlue "\nSTATISTICAL ANALYSIS"

		# Check whether corrected tracks exist and copy them in the tmp directory
		if [[ -e $data/tracks.csv ]]; then
			echo "Corrected track(s) .......OK"
			cp $data/tracks.csv $tmp/
		else
			error "Corrected larvae tracks missing. Use:\n\t $0 correct $id"
			continue
		fi

		# Compute position and direction statistics and store the result in stats.csv
		(cd $RES && R -q --slave --args ${tmp} ${diam} ${psub} ${binangle} < stats.R)

		status $? "R exited abnormally"

		# Display the plots in a PDF reader if asked to do it
		if [[ $display == "TRUE" ]]; then
			
			# Detect the name of the PDF reader
			pdfReader=""
			if [[ $(uname) == "Darwin" ]]; then
				# on Mac OS X use "open" to open with the default app associated with PDFs
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
				$pdfReader > /dev/null 2>&1 $tmp/plots*.pdf &
				status $? "The PDF reader exited abnormally"
			fi
		fi

		echo "Save statistics and graphics"
		commit_changes "stats.csv" plots*.pdf
	fi


	# CLEAN WORKSPACE
	#------------------------------------------------------------

	# Move data to the storage directory
	if [[ $STORE == "TRUE" ]]; then
		echoBlue "\nDATA STORAGE"
		# see lib_discus for the details of the function sync_data
		sync_data $work $storage store $id
		status $? "Check command line arguments"
	fi

	# removing the temporary directory
	if [[ -e $tmp ]]; then
		# NB: this rm -Rf is potentially harmful, so we take precautions by testing the existence of the file before hand
		rm -Rf $tmp
		status $? "Could not remove temporary directory"
	fi

done

fi

echo -e "\nDone. Bye"

exit 0

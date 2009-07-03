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

# Give a bit of room
echo ""



# SOURCE
#-----------------------------------------------------------------------

# set source directories
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


# Help message (should be done early)
# detect whether we just want the help (this overrides all the other options and we want it here to avoid dealing with the config file etc when the user just wants to read the help)
echo $* | grep -E -e "\b(h|help)\b" > /dev/null
if [[ $? -eq 0 ]]; then
	help
	exit 0
fi



# CONFIGURATION
#-----------------------------------------------------------------------

# Set defaults

# Parameters: stick from one deployment to the next
# ImageJ memory, in mb (should not be more than 2/3 of available physical RAM)
ijMem=1000
# aquarium boundary coordinates
aquariumBounds="10,10,300,300"
# angle between the top of the picture and the forward direction of the compass
cameraCompassAngle=90
# diameter of the aquarium, in cm
aquariumDiam=40
# root directory containing directories for all deployments (workspace)
work=$HERE
# storage directory containing directories for all deployments (photo source and backup)
storage=""

# Actions: determined on the command line, all FALSE by default
# perform any action
ACT=FALSE
# get images from video
VIDEO=FALSE
# stabilize images
STAB=FALSE
# perform calibration?
CALIB=FALSE
# track compass?
TRACK_COMP=FALSE
# track larva(e)?
TRACK_LARV=FALSE
# correct tracks?
CORR=FALSE
# perform statistical analysis of current track?
STATS=FALSE
# get data from the storage directory
GET=FALSE
# store data to the storage directory
STORE=FALSE
# give information about the content of the data/storage directory
STATUS=FALSE

# Options: set in the config file or on the command line
# deployment number (i.e. deployment directory name)
deployNb=""
# subsample images every 'sub' seconds to speed up the analysis
sub=1
# subsample positions each 'psub' seconds for the statistical analysis, to allow independence of data
psub=5
# whether to display plots or not after the statistical analysis
displayPlots=FALSE
# use the storage directory status rather than the data directory
storageStatus=FALSE
# whether the camera is looking up at the arena
lookingUp=FALSE


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
			storageStatus=TRUE
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
			TRACK_COMP=TRUE
			TRACK_LARV=TRUE
			CORR=TRUE
			STATS=TRUE
			ACT=TRUE
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
			write_pref $configFile aquariumDiam
			shift 2 ;;
		-a|-angle)
			cameraCompassAngle="$2"
			write_pref $configFile cameraCompassAngle
			shift 2 ;;
		-m|-mem)
			ijMem="$2"
			write_pref $configFile ijMem
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
	error "ImageJ not found"
	echo -e "Download the platform independent file from\n  http://rsbweb.nih.gov/ij/download.html\nand place ij.jar in $ijPath"
	exit 1
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
if [[ ( $GET == "TRUE" || $STORE == "TRUE" ) && $storage == "" ]]; then
	error "Exchange of data with storage requested\n  but no storage directory specified"
	exit 1
fi

if [[ $STATUS == "TRUE" && $storageStatus == "TRUE" && $storage == "" ]]; then
	error "Status of the storage directory requested but no storage directory specified"
	exit 1
fi

if [[ ( ( $GET == "TRUE" || $STORE == "TRUE" ) || ( $STATUS == "TRUE" && $storageStatus == "TRUE" ) ) && ! -d $storage ]]; then
	error "Storage directory\n  $storage\n  does not exist"
	exit 1
fi



# STATUS
#------------------------------------------------------------
# If status is requested, print first and exit
if [[ $STATUS == "TRUE" ]]; then
	echoBlue "DATA SUMMARY"
	if [[ $storageStatus == "TRUE" ]]; then
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
# if deployNb is a range, expand it
deployNb=$(expand_range "$deployNb")
status $? "Could not interpret deployment number"
# if deployNb is not specified, process all available deployments
if [[ $deployNb == "" && $ACT == "TRUE" ]]; then
	warning "No deployment number specified.\nIterating command(s) on all available deployments"
	deployNb=$(ls $work | sort -n)
fi

if [[ $ACT == "TRUE"  ]]; then

for id in $deployNb; do

	# PREPARE WORKSPACE
	#-----------------------------------------------------------------------

	echoBold "\nDEPLOYMENT $id"

	# Current deployment directory
	data="$work/$id"

	# If requested, get it from the storage
	if [[ $GET == "TRUE" ]]; then
		echoBlue "\nDATA IMPORT"
		sync_data $work $storage get $id
		status $? "Check command line arguments"
	fi
	# otherwise test its existence
	if [[ ! -d $data ]]; then
		error "Deployment directory does not exist:\n  $data"
		exit 1
	fi

	# Source of images (pictures or video)
	pics="$data/pics"
	videoFile="$data/video_hifi.mov"
	if [[ $VIDEO == "TRUE" && ! -e $videoFile ]]; then
		error "Cannot find video file:\n  $pics"
		exit 1
	elif [[ ( $STAB == "TRUE" || $CALIB == "TRUE" || $TRACK_LARV == "TRUE" || $TRACK_COMP == "TRUE" ) && ! -d $pics ]]; then
		error "Cannot find pictures directory:\n  $pics"
		exit 1
	fi

	# Temporary directory, where all operations are done
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

		# tests for the existence of MPlayer
		mplayer=$(which mplayer)
		status $? "mplayer not found. Please install it."

		# get the frame rate of the video
		videoFPS=$($mplayer 2>/dev/null -vo null -nosound -frames 1 $videoFile | awk '/VIDEO/ {print $5}')
		videoFPS=$(echo $videoFPS | cut -d " " -f 1)
		# compute the step size at which to export frames based of the subsampling parameter
		frameStep=$(echo "$videoFPS * $sub" | bc -l)
		# round the number
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

		# rename output files (so that they are handled correctly in R afterwards)
		# = suppress the zeros
		for img in $(ls $tmp/pics); do
			mv $tmp/pics/$img $tmp/pics/${img//0/}
		done

		# Set time in the EXIF properties of the images
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
			# assign the dates using exiftool
			for (i in seq(along=pics)) {
				date = format(dates[i], "%Y:%m:%d %H:%M:%S")
				subsec = substr(format(dates[i], "%OS"),4,5)
				system(paste("exiftool -overwrite_original -CreateDate='",date,"' -SubsecTime='",subsec,"' ${tmp}/pics/",pics[i],sep=""))
			}
EOF
)
		status $? "R exited abnormally"

		echo "Save exported images"
		commit_changes pics

	fi

	# Image stabilization
	if [[ $STAB == "TRUE" ]]; then
		echo "Stabilize images"
		# Use ImageJ to
		# - open images as a stack
		# - stabilize the stack
		# - export back the slices as JPEG images
		# We do all that in batch mode, withut user interaction
		$javaCmd -jar $ijPath/ij.jar -ijpath $ijPath/plugins/ -batch $ijPath/macros/Run_Image_Stabilizer.ijm $data > /dev/null 2>&1

		status $? "ImageJ exited abnormally"

		echo "Copy images metadata"
		for img in $(ls $data/pics); do
			# Copy all metadata from the original image in $data
			# -P	except the modification date (use current time)
			# -q	be quiet
			$exiftool -P -q -overwrite_original -TagsFromFile $data/pics/$img -all:all $tmp/pics/$img
		done

		echo "Overwrite original images with stabilized ones"
		commit_changes pics

	fi

	# Calibration
	if [[ $CALIB == "TRUE" ]]
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
		$javaCmd -Xmx200m -jar $ijPath/ij.jar -eval "       \
		run('Image Sequence...', 'open=${pics}/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
		makeOval(${aquariumBounds});                        \
		waitForUser('Aquarium selection',                   \
			'If necessary, alter the selection to fit the aquarium better.\n               \
			\nPress OK when you are done');                 \
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
			aquariumBounds=$(sed \1d ${tmp}/bounding_aquarium.txt | awk -F " " {'print $2","$3","$4","$5'})

			write_pref $configFile aquariumBounds
		else
			warning "Cannot save bounding box of the aquarium"
		fi

		echo "Save aquarium radius"

		commit_changes "coord_aquarium.txt"
	fi

	# Tracking function
	# Has to be local because it currently references many global variables
	function manual_track ()
	#
	# Track objects manually
	#
	{
		# Save all files given on the command line
		outputFiles=$@
		# The result of the tracking is saved in the first one
		resultFileName=$1

		# Detect the time lapse between images
		# we use an inline R script given how easy it is to deal with time in R
		# just how cool is that!?
		interval=$(R -q --slave << EOF
			# get the time functions
			source("src/lib_image_time.R")
			# get the first x images names
			images=system("ls -1 ${pics}/*.jpg | head -n 10", intern=TRUE)
			# compute time lapse and send it to standard output
			cat(time.lapse.interval(images))
EOF
)
# NB: for the heredoc (<< construct) to work, there should be no tab above
		status $? "R exited abnormally"

		# Deduce the lag when subsampling images
		subImages=$(($sub / $interval))
		# NB: this is simple integer computation, so not very accurate but OK for here
		# when $sub is smaller than $interval (i.e. subImages < 1 i.e. = 0 here because we are doing integer computation) it means we want all images.
		# so subImages should in fact be 1
		if [[ $subImages -eq 0 ]]; then
			subImages=1
		fi

		# Determine whether to use a virtual stack or a real one
		# total number of images
		allImages=$(ls -1 ${pics}/*.jpg | wc -l)
		# nb of images opened = total / interval
		nbFrames=$(($allImages / $subImages))
		# when there are less than 100 frames, loading them is fast and not too memory hungry
		if [[ $nbFrames -le 100 ]]; then
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
		$javaCmd -Xmx${ijMem}m -jar ${ijPath}/ij.jar      \
		-ijpath ${ijPath}/plugins/ -eval "                \
		run('Image Sequence...', 'open=${pics}/*.jpg number=0 starting=1 increment=${subImages} scale=100 file=[] or=[] sort ${virtualStack}'); \
		run('Manual Tracking');                           \
		waitForUser('Track finished?',                     \
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
		$javaCmd -Xmx200m -jar $ijPath/ij.jar -eval "       \
		run('Image Sequence...', 'open=${pics}/*.jpg number=1 starting=1 increment=1 scale=100 file=[] or=[] sort'); \
		setTool(7);                                         \
		waitForUser('Compass calibration',                  \
			'Please click the center of the compass you intend to track.\n      \
			\nPress OK when you are done');                 \
		run('Set Measurements...', ' centroid invert redirect=None decimal=3'); \
		run('Measure');                                     \
		saveAs('Measurements', '${tmp}/coord_compass.txt'); \
		run('Quit');"  > /dev/null 2>&1

		status $? "ImageJ exited abnormally"

		echo "Save compass coordinates"
		manual_track compass_track.txt coord_compass.txt
	fi

	# Track larvae
	if [[ $TRACK_LARV == "TRUE" ]]; then
		echoBlue "\nTRACKING LARVAE"
		manual_track larvae_track.txt
	fi

	# Correction
	if [[ $CORR == "TRUE" ]]
	then
		echoBlue "\nCORRECTION OF TRACKS"

		# We start by checking that everything is available and copy stuff to the temporary directory

		OK=0

		if [[ ! -e $data/coord_aquarium.txt ]]
		then
			error "Aquarium coordinates missing. Use:\n\t$0 calib $id"
			OK=1
		else
			echo "Aquarium coordinates ....OK"
			cp $data/coord_aquarium.txt $tmp
		fi

		if [[ ! -e $data/compass_log.csv ]]; then

			warning "Numeric compass track missing.\n  Falling back on manual compass track."

			if [[ ! -e $data/compass_track.txt ]]; then
				error "Manual compass track missing. Use:\n\t $0 compass $id"
				OK=1
			else
				echo "Compass track ..........OK"
				cp $data/compass_track.txt $tmp
				compass="manual"
			fi

			if [[ ! -e $data/coord_compass.txt ]]
			then
				error "Compass coordinates missing. Use:\n\t $0 compass $id"
				OK=1
			else
				echo "Compass coordinates .....OK"
				cp $data/coord_compass.txt $tmp
			fi

		else
			echo "Compass track ...........OK"
			cp $data/compass_log.csv $tmp
			compass="auto"
		fi

		if [[ ! -e $data/larvae_track.txt ]]
		then
			error "Larva(e) track(s) missing. Use:\n\t $0 larva $id"
			OK=1
		else
			echo "Larva(e) track(s) .......OK"
			cp $data/larvae_track.txt $tmp
		fi


		if [[ "$OK" == "1" ]]
		then
			echo "Exiting..."
			rm -f $tmp/*
			exit 1
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
		( cd $RES && R -q --slave --args ${tmp} ${aquariumDiam} ${cameraCompassAngle} ${lookingUp} < correct_tracks.R )

		status $? "R exited abnormally"

		echo "Save track"

		commit_changes "tracks.csv"

	fi

	# Tracks analysis
	if [[ $STATS == "TRUE" ]]
	then
		echoBlue "\nSTATISTICAL ANALYSIS"

		# Checking for tracks existence and copy the tracks in the tmp directory
		if [[ -e $data/tracks.csv ]]; then
			echo "Corrected track(s) .......OK"
			cp $data/tracks.csv $tmp/
		else
			error "Corrected larvae tracks missing. Use:\n\t $0 correct $id"
			exit 1
		fi

		(cd $RES && R -q --slave --args ${tmp} ${aquariumDiam} ${psub} < stats.R)

		status $? "R exited abnormally"

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
		sync_data $work $storage store $id
		status $? "Check command line arguments"
	fi

	# Cleaning
	if [[ -e $tmp ]]; then
		# NB: this rm -Rf is potentially harmful, so take precautions
		rm -Rf $tmp
		status $? "Could not remove temporary directory"
	fi

done

fi

echo -e "\nDone. Bye"

exit 0

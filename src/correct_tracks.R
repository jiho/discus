#
# 	BlueBidule
#
#		Correct tracks to cardinal coordinates
#
#	(c) Jean-Olivier Irisson 2005-2009
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# Functions to deal with circular data
library("circular", warn.conflicts=FALSE)
library("plyr", warn.conflicts=FALSE)
source("lib_circular_stats.R")

# Parse command line arguments
args = commandArgs(trailingOnly=TRUE)
if (length(args) != 3) {
	stop("Not enough arguments")
}
prefix = args[1]
aquariumDiam = as.numeric(args[2])
cameraCompassDeviation = as.numeric(args[3])

# Set working directory
setwd(prefix)


## Read data
#-----------------------------------------------------------------------

# larvae tracks are recorded from ImageJ "Manual tracking"
trackLarva = read.table("larvae_track.txt", header=T, sep="\t")
trackLarva = trackLarva[,-1]
# WARNING: The origin of the position is the upper-left corner

# read compass record
# it can either be a record from the numerical compass or from the backup, physical compass
if (file.exists("compass_log.csv")) {

	# This is the log oc the numeric compass
	trackCompass = read.table("compass_log.csv", header=TRUE, sep=",", as.is=TRUE)
	trackCompass$date = as.POSIXct(strptime(trackCompass$date, format="%Y-%m-%d %H:%M:%S"))
	compassSource = "numeric"

	# subtract the camera-compass orientation correction
	trackCompass$heading = trackCompass$heading - cameraCompassDeviation
	# this means that trackCompass$heading now correspond to the heading of the top of the picture

	# convert to the appropriate circular class
	trackCompass$heading = circular(trackCompass$heading, unit="degrees", template="geographics", modulo="2pi")

} else if (file.exists("compass_track.txt")) {

	# Else we default to a manual record of the compass track
	trackCompass = read.table("compass_track.txt", header=TRUE, sep="\t", as.is=TRUE)
	trackCompass = trackCompass[,-1]
	compassSource = "manual"

	# also read the coordinates of the center of the compass, to be able to compute the movement in polar coordinates
	coordCompass = read.table("coord_compass.txt", header=TRUE, sep="\t")
	coordCompass = coordCompass[,c("X","Y")]

	# TODO compute headings in polar coordinates, interpolate the track etc.
	# i.e. make it similar to the automatic compass track as much as possible.
}

# Read calibration data
coordAquarium = read.table("coord_aquarium.txt", header=TRUE, sep="\t", col.names=c("nb","X","Y","Perim"))
coordAquarium = coordAquarium[,-1]


## Reformat tracks
#-----------------------------------------------------------------------

# Split larvae tracks in a list
tracks = split(trackLarva, trackLarva$trackNb)
nbTracks = length(tracks)

# Add time stamps to the tracks
# check for the existence of exiftool
exiftool = system("which exiftool",intern=TRUE)
if (length(exiftool) == 0) {
	stop("Please install exiftool http://www.sno.phy.queensu.ca/~phil/exiftool/")
}
# read the exact time with split seconds with exiftool
picTimes = system(paste(exiftool,"-T -p '$CreateDate.$SubsecTime' ../*.jpg"), intern=TRUE)
options("digits.secs" = 2)
picTimes = as.POSIXct(strptime(picTimes, format="%Y:%m:%d %H:%M:%OS"))
# read the names of the images
images = as.numeric(system("ls -1 ../*.jpg | cut -d '/' -f 2 | cut -d '.' -f 1", intern=T))
# keep split seconds but also round times to full seconds
picTimes = data.frame(imgNb=images, exactDate=picTimes, date=round(picTimes))
# add to tracks
tracks = llply(tracks, merge, picTimes)


## Compute larvae tracks in a cardinal reference
#-----------------------------------------------------------------------

# Interpolate compass positions at every point in time in the tracks
tracks = llply(tracks, function(x, compass) {
	x$compass = approx.circular(compass$date, compass$heading, x$exactDate)$y
	return(x)
}, trackCompass)


# Only keep data where calibration is available
tracks = llply(tracks, function(x){x=x[!is.na(x$compass),]})


# Correct for the rotation of the compass relative to the bearing in the first frame
# for all larvae tracks
for (l in 1:nbTracks) {

	t = tracks[[l]]

	# convert track to polar coordinates
	t[,c("theta","rho")] = car2pol(t[,c("x","y")], c(coordAquarium$X,coordAquarium$Y))

	# theta is in trigonometric reference:
	# 	measures the angle, in radians, between the larva and the horizontal, in counter clockwise direction.
	# we start by converting it to a compass heading
	t$theta = trig2geo(t$theta)

	# we then correct for the rotation by subtracting the compass heading of the top of the picture
	t$thetaCor = t$theta - t$compass

	# for un corrected track to be comparable to the corrected one, they need to start in the same reference as the corrected track. So we subtract the first angle to every frame
	t$theta = t$theta - t$compass[1]

	# finally, since we are looking at the aquarium and compass from below, the E and W are inverted. We change that by shifting the rotation direction
	# _set_ it to counter clockswise (does not alter the numbers, just the attributes)
	a = circularp(t$theta)
	a$rotation="counter"
	circularp(t$theta) = a
	circularp(t$thetaCor) = a
	# _convert_ back to clockwise (this actually changes the numbers)
	t$theta = conversion.circular(t$theta, units="degrees", rotation="clock")
	t$thetaCor = conversion.circular(t$thetaCor, units="degrees", rotation="clock")

	# recompute cartesian positions from the polar definition
	t[,c("x","y")] = pol2car(t[,c("theta","rho")])
	t[,c("xCor","yCor")] = pol2car(t[,c("thetaCor","rho")])

	# convert x, y, and rho to human significant measures (mm)
	px2cm = aquariumDiam/(coordAquarium$Perim/pi)
	px2mm = px2cm*10
	t[,c("x","y","xCor","yCor","rho")] = t[,c("x","y","xCor","yCor","rho")] * px2mm
	t$rhoCor = t$rho

	# make position angles real bearings: they are already measured clockwise from the north, now we also make sure they only contain positive value
	t$theta = (t$theta + 360) %% 360
	t$thetaCor = (t$thetaCor + 360) %% 360

	# reorganize the columns of the dataframe
	tracks[[l]] = t[,c("trackNb", "sliceNb", "imgNb", "exactDate", "date", "x", "y", "theta", "rho", "xCor", "yCor", "thetaCor", "rhoCor")]

}


## Saving tracks for statistical analysis and plotting
#-----------------------------------------------------------------------

# Take omitted frames into account in larvae tracks
tracks = llply(tracks, function(x, imgNames) {
	t = as.data.frame(matrix(nrow=length(imgNames),ncol=length(names(x))))
	names(t) = names(x)
	t$trackNb = x$trackNb[1]
	t$imgNb = imgNames
	class(t$date) = class(x$date)
	class(t$exactDate) = class(x$exactDate)
	t[ t$imgNb %in% x$imgNb,] = x;
	return(t);
}, images)

# Concatenate all tracks into one data.frame
tracks = do.call("rbind", tracks)

# Write it to a csv file
write.table(tracks, file="tracks.csv", sep=",", row.names=F)

#
# 	BlueBidule
#
#		Reformats data and performs statistical analysis
#
#
#	(c) Jean-Olivier Irisson 2005-2007
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# References for conversion to real world measures and environment variables
#-----------------------------------------------------------------------
# dimension reference (aquarium diameter in mm and in px)
realAquariumDiameter = 381
aquarium = read.table("coord_aquarium.txt");
names(aquarium) = c("centerX", "centerY", "perimeter")
px2mm = realAquariumDiameter/(aquarium$perimeter/pi)

# time reference (frames per second)
fps = as.numeric(system("echo $FPS", intern=TRUE))
# TODO: store video FPS at video analysis time and read it here in case we changed it in between

# get VIDEOID as an identifier for this dataset
videoId = system("echo $VIDEOID", intern=TRUE)

# get number of bins in rose.diagrams
nbBins = as.numeric(system("echo $NB_PIE", intern=TRUE))


# Read data and library files
#-----------------------------------------------------------------------
# get useful functions
library("circular")
source("lib_circular_stats.R")

# read corrected tracks
readTracks = read.table("tracks.csv", header=TRUE, sep=",")

# set the correct circular class for the positions bearings
# NB: we wrote them as regular angles = in radians, measured from zero in counter clockwise direction. we'll keep them this way for the computation, instead of using the "geographics" template because it seems to cause issues (in particular with range.circular)
readTracks$bearing = circular(readTracks$bearing)
readTracks$bearingCor = circular(readTracks$bearingCor)

# reorganize tracks in a list by [[trackNb]][[corrected/notCorrected]]
trackNumbers = levels(as.factor(readTracks$trackNb))
nbTracks = length(trackNumbers)
tracks = list()
for (t in 1:nbTracks) {
	cTrack = readTracks[readTracks$trackNb==t,]
	noCor = subset(cTrack,select=c(frameNb,x,y,bearing))
	cor = subset(cTrack,select=c(frameNb,xCor,yCor,bearingCor))
	names(cor) = names(noCor)
	tracks[[t]] = list(cor,noCor)
	names(tracks[[t]]) = c("corrected","uncorrected")
}
names(tracks) = trackNumbers



# Compute swimming direction and speed for larvae tracks
#-----------------------------------------------------------------------
for (t in 1:nbTracks) {
	for (l in c("corrected","uncorrected")) {
		# compute swimming direction = position at t+1 - position at t
		dirs = tracks[[t]][[l]][2:nrow(tracks[[t]][[l]]),c("x","y")] - tracks[[t]][[l]][1:(nrow(tracks[[t]][[l]])-1),c("x","y")]
		dirs = rbind(NA,dirs)
		# convert it to polar coordinates
		dirsPol = car2pol(dirs,c(0,0))
		# extract angles and convert them to bearings
		tracks[[t]][[l]]$directionBearing = circular(dirsPol$theta)
		# This conversion only displaces the origin and converts the numbers but it does not rotate anything, therefore we have the correct directions here
		
		# compute speeds in mm/s
		tracks[[t]][[l]]$speed = sqrt(dirs$x^2+dirs$y^2)/(1/fps)
	}
}


# Statistics
#--------------------------------------------------------------------

# Prepare output dataframe
colNames = c("id", "trackNb", "type", "correction", "sampleSize", "meanBearing", "circularDispersion", "angularDeviation", "rayleighR", "pValue")
stats = as.data.frame(matrix(nrow = 0,ncol = length(colNames)))
names(stats) = colNames
# stats$meanBearing = circular(stats$meanBearing,units="radians")

# Set bootstrapping options
nRepet = 1000
percentage = 5
# nRepet = 3
# percentage = 100
# TODO set bootstrap parameters from the shell script (taking -t into account)

# Prepare plots
# colors
posColor = rgb(106,134,173,maxColorValue = 255)
dirColor = rgb(198,107,104,maxColorValue = 255)
speedColor = rgb(127,167,110,maxColorValue = 255)
# max speed in mm/s
maxSpeed = 300
# min speed to consider in order to avoid errors
maxErrorInPx = 2.8
maxErrorInMm = maxErrorInPx * px2mm
# remove speed which are potentially more than 1/4 of random noise
minSpeed = maxErrorInMm * 4
# open pdf device
pdf(file = paste(videoId,"-graphics.pdf",sep=""),title = videoId,width = 6,height = 6)

for (t in 1:nbTracks) {
	trackId = paste("Id =",videoId,", Larva =",t)

	# Plot trajectory
	#--------------------------------------------------------------------
	plot.traject(tracks[[t]], realAquariumDiameter/2, sub = trackId, col = posColor)
	
	# Position statistics
	#--------------------------------------------------------------------
	# Positions are not independant from one another in time, therefore we have to use a bootstrap technique and resample them
	# we start by removing NA positions because they do not count in the stats
	cTrack = tracks[[t]]
	cBearings = list(corrected=na.exclude(cTrack[["corrected"]]$bearing), uncorrected=na.exclude(cTrack[["uncorrected"]]$bearing))
	cAutocorell = list(corrected=NA,uncorrected=NA)
	nbObs = unique(sapply(cBearings,length))
	if (length(nbObs)!=1) {
		stop("Not the same number of non NA bearings between corrected and uncorrected tracks")
	}
	nbSampled = as.integer(nbObs*percentage/100)
	for (i in 1:nRepet) {
		# take a sample of the indices
		indexes = sample(c(1:nbObs),nbSampled,replace = F)
		for (l in c("corrected","uncorrected")) {
			if (l=="corrected") {
				correction = TRUE
			} else {
				correction = FALSE
			}
			# extract sampled indexes
			bearings = cBearings[[l]][indexes]
			# evaluate data independance for corrected tracks
			autocorell = check.indep(bearings,name="",plot = FALSE)
			# TODO: check independance of x,y position rather than bearing because angles can be close and still appear independant if trated as cartesian coordinates (ex: 350 and 10 degrees)
			if (i==1) {
				cAutocorell[[l]] = autocorell
			} else {
				cAutocorell[[l]] = rbind(cAutocorell[[l]],autocorell)
			}
			# perform circular stats
			data = circ.stats(bearings, videoId, names(tracks)[t], "position", correction)
			# store this in the output dataframe
			stats = rbind(stats,data)
		}
	}
	
	# Position plot
	#--------------------------------------------------------------------
	# independance check: mean/max autocorrelogram (since it can be positive or negative by chance alone we need use absolute value)
	absAutocorell = lapply(cAutocorell,apply,2,abs)
	meanAutocorell = lapply(absAutocorell,apply,2,mean)
	maxAutocorell = lapply(absAutocorell,apply,2,max)
	for (l in c("corrected","uncorrected")) {
		plot(meanAutocorell[[l]], type="h", xlab="Lag", ylab="ACF",main=paste("Absolute mean autocorrellogram for resampled",l,"positions"),ylim=c(0,1))
		plot(maxAutocorell[[l]], type="h", xlab="Lag", ylab="ACF",main=paste("Absolute max autocorrellogram for resampled",l,"positions"),ylim=c(0,1))
	}
	
	# rose diagram of the bearings of _significant_ mean vectors, for corrected and un-corrected version of current track
	cPosStats = stats[stats$trackNb==t & stats$type=="position" & stats$pValue<0.05,c("correction","meanBearing")]
	names(cPosStats) = c("correction","angles")
	cPosList = list(cPosStats[cPosStats$correction,],cPosStats[!cPosStats$correction,])
	names(cPosList) = c("corrected","uncorrected")
	plot.rose(cPosList, main="Bearing of significant mean position vectors",sub = trackId,bins = nbBins, col = posColor)
	# TODO: evaluate the percentage of significant positions vectors
	
	# Direction statistics
	#--------------------------------------------------------------------
	cTrack = tracks[[t]]
	for (l in c("corrected","uncorrected")) {
		if (l=="corrected") {
			correction = TRUE
		} else {
			correction = FALSE
		}
		# remove movement at small speeds that is largely influenced by random errors when detecting the larva
		cTrack[[l]] = cTrack[[l]][cTrack[[l]]$speed>minSpeed,]

		# check for independance of data in time
		dummy = check.indep(cTrack[[l]]$directionBearing,name = paste(l,"directions"));

		# perform circular stats
		data = circ.stats(cTrack[[l]]$directionBearing, videoId, names(tracks)[t], "direction", correction)
		
		# store this in the output dataframe
		stats = rbind(stats,data)		
	}

	# Direction plot (only speeds above threshold)
	#--------------------------------------------------------------------
	if (nrow(cTrack[[1]])>1 & nrow(cTrack[[2]])>1) {
		# plot swimming vectors
		plot.dirs(cTrack, lim = c(-maxSpeed,maxSpeed), main="Swimming vectors (mm/s)", sub = trackId, col = dirColor)
		# plot swimming directions
		library("reshape")
		cTrack = lapply(cTrack,rename,c(directionBearing="angles"))
		plot.rose(cTrack, angleType="directionBearing", main="Swimming directions", sub = trackId, bins = nbBins, col = dirColor)		
	}

	# Speed histogram (keep small speeds also)
	#--------------------------------------------------------------------
	plot.hist(tracks[[t]], threshold = minSpeed, breaks = 0:maxSpeed, main="Swimming speed histogram", sub = trackId, col = speedColor, xlim = c(0,maxSpeed))
}

# closes the pdf graph device
dev.off()


# Write statistics to a csv file
#--------------------------------------------------------------------
# TODO investigate the posibility to write the angles in geographic template
write.table(stats,file="stats.csv",sep=",",row.names = FALSE)


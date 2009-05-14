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

# suppress warnings
options(warn=-1)

# get useful functions
library("boot", warn.conflicts=FALSE)
library("proto", warn.conflicts=FALSE)
library("grid", warn.conflicts=FALSE)
library("plyr", warn.conflicts=FALSE)
library("reshape", warn.conflicts=FALSE)
library("circular", warn.conflicts=FALSE)
library("ggplot2", warn.conflicts=FALSE)
source("lib_circular_stats.R")

# Parse command line arguments
args = commandArgs(trailingOnly=TRUE)
if (length(args) != 3) {
	stop("Not enough arguments")
}
prefix = args[1]
aquariumDiam = as.numeric(args[2])
subsampleTime = as.numeric(args[3])
# In case we need to call it without the shell script
# prefix="/home/jiho/current_data/1/tmp/"
# aquariumDiam = 40
# subsampleTime = 15

# # min speed to consider in order to avoid errors
# maxErrorInPx = 2.8
# maxErrorInMm = maxErrorInPx * px2mm
# # remove speed which are potentially more than 1/4 of random noise
# minSpeed = maxErrorInMm * 4


setwd(prefix)


## Read and reformat data
#-----------------------------------------------------------------------

# read corrected tracks
tracks = read.table("tracks.csv", header=TRUE, sep=",")

# set the correct circular class for the positions bearings
# = measured from the north, in degrees, in clockwise direction
tracks$theta = circular(tracks$theta, units="degrees", template="geographics")
tracks$compass = circular(tracks$compass, units="degrees", template="geographics")
# NB: we might need them as regular angles = in radians, measured from zero in counter clockwise direction, because bearings seem to cause issues (in particular with range.circular)

# set the class of times
options("digits.secs" = 1)
tracks$exactDate = as.POSIXct(tracks$exactDate)
tracks$date = as.POSIXct(tracks$date)

# reorganize tracks in a list by [[trackNb]][[original/corrected]]
tracks = llply(split(tracks, tracks$trackNb), function(x){split(x, x$correction)})
nbTracks = length(tracks)

# Compute swimming direction and speed
for (i in 1:nbTracks) {
	tracks[[i]] = llply(tracks[[i]], function(t) {
		# Compute swimming directions
		# compute swimming vectors in x and y directions
		# = position at t+1 - position at t
		dirs = t[2:nrow(t),c("x","y")] - t[1:(nrow(t)-1),c("x","y")]
		dirs = rbind(NA,dirs)
		# convert to headings by considering that these vectors originate from 0,0
		headings = car2pol(dirs, c(0,0))$theta
		# cast to the appropriate circular class
		headings = conversion.circular(headings, units="degrees", template="geographics", modulo="2pi")
		# store that in the orignal dataframe
		t$heading = headings

		# Compute speeds in cm/s
		# compute time difference between pictures
		dirs$interval = c(NA,as.numeric(diff(t$exactDate)))
		# compute speed from displacement and interval
		t$speed = sqrt(dirs$x^2 + dirs$y^2) / dirs$interval

		return(t)
	})
}


## Statistics and plots
#-----------------------------------------------------------------------

# Compute positions statistics
p = ldply(tracks, function(t, ...){
	pp = ldply(t, function(x, ...){circ.stats(x, ...)}, ...)
	names(pp)[1] = "correction"
	pp$correction = as.logical(as.character(pp$correction))
	pp[ ! pp$correction, "mean"] = NA
	return(pp)
}, sub=subsampleTime)
names(p)[1] = "trackNb"

# Display statistical results
# TODO improve the display
cat("Statistics:\n")
print(p)


# TODO compute direction statistics while cutting direction data for speeds < threshold
d = data.frame(kind="direction")

# write them to file
p$kind = "position"

stats = rbind.fill(p, d)
write.table(stats, file="stats.csv", row.names=FALSE, sep=",")



# Prepare plots
plots = llply(tracks, .fun=function(t, aquariumDiam) {

	# detect the number of successive images to plot appropriate plots
	# = if there anre no successive images (usually because of resampling) there is no point in plotting trajectory or computing speeds
	x = t[[1]]
	successive = is.na(x$date) + is.na( c(NA, x$date[-nrow(x)]) )
	# successive = 0 when there are successive images
	successive = sum(successive == 0)

	ggplots = list()

	# compass trajectory
	# we isolate one track (the compass track is the same in both of them)
	x = t[[1]]
	# make imgNb relative
	x$imgNb = x$imgNb-x$imgNb[1]
	# plot as points (path causes issues when the trajectory traverses the 360-0 boundary)
	compass = ggplot(x) + geom_point(aes(x=compass, y=imgNb, colour=imgNb), alpha=0.5, size=3) + polar() + opts(title="Compass rotation") + scale_y_continuous("", breaks=NA, limits=c(-max(x$imgNb), max(x$imgNb)))
	# NB: th y scale is so we can see the bearings of the first records

	ggplots = c(ggplots, list(compass))

	if (successive > 0) {
		# trajectory (only if there are at least 2 successive positions)
		traj = llply(t, function(x, radius){
			x$time = as.numeric(x$date-x$date[1])
			ggplot(x) + geom_path(aes(x=x, y=y, colour=time), arrow=arrow(length=unit(0.01,"native")) ) + xlim(-radius,radius) + ylim(-radius,radius) + coord_equal() + opts(title=paste("Trajectory\ncorrection =", x$correction[1]))
			# TODO add a circle around
		}, aquariumDiam/2)

		ggplots = c(ggplots, traj)
	}


	# point positions
	positions = llply(t, function(x){
		# ggplot does not deal with the circular class
		x$theta = as.numeric(x$theta)
		# plot
		ggplot(x) + geom_point(aes(x=theta, y=1), alpha=0.1, size=4) + scale_y_continuous("", limits=c(0,1.05), breaks=NA) + polar() + opts(title=paste("Positions\ncorrection =", x$correction[1]))
	})


	# rose positions
	pHist = llply(t, function(x){
		# ggplot does not deal with the circular class
		x$theta = as.numeric(x$theta)
		# plot
		ggplot(x) + geom_bar(aes(x=theta), binwidth=45/4) + polar() + opts(title=paste("Histogram of positions\ncorrection =", x$correction[1]))
		# TODO Add mean vector
	})

	# density positions
	pDens = llply(t, function(x){
		# use a custom function for circular density
		ggplot() + geom_density_circular(x$theta, na.rm=T, bw=100) + polar() + opts(title=paste("Density distribution of positions\ncorrection =", x$correction[1]))
	})

	ggplots = c(ggplots, positions, pHist, pDens)

	if (successive > 0) {
		# rose directions
		dHist = llply(t, function(x){
			# ggplot does not deal with the circular class
			x$heading = as.numeric(x$heading)
			# plot
			ggplot(x) + geom_bar(aes(x=heading), binwidth=45/4) + polar() + opts(title=paste("Histogram of swimming directions\ncorrection =", x$correction[1]))
			# TODO Add mean vector
		})


		# speed distribution
		speeds = llply(t, function(x, maxSpeed){
			# prepare the scale and the base plot
			scale_x = scale_x_continuous("Speed (cm/s)", limits=c(0,max(max(x$speed, na.rm=T),maxSpeed)))
			p = ggplot(x, aes(x=speed)) + scale_x
			# add geoms
			sHist = p + geom_histogram(binwidth=0.5) + opts(title=paste("Histogram of swimming speeds\ncorrection =", x$correction[1]))
			sDens = p + geom_density() + opts(title=paste("Density distribution of swimming speeds\ncorrection =", x$correction[1]))
			return(list(sHist, sDens))
		}, 5)
		# regroup histograms and densities
		speeds = list(speeds[[1]][[1]], speeds[[2]][[1]], speeds[[1]][[2]], speeds[[2]][[2]])

		ggplots = c(ggplots, dHist, speeds)
	}

	return(ggplots)
}, aquariumDiam)


cat("Plotting each track\n")

# Plot to PDF file
for (name in names(tracks)) {
	# reduce the number of hierachy levels to ease plotting
	p = unlist(plots[name], F)
	if (length(tracks) > 1) {
		filename = paste("plots-",name,".pdf",sep="")
	} else {
		filename="plots.pdf"
	}
	pdf(file=filename)
	dummy = l_ply(p, print, .progress="text")
	dummy = dev.off()
}

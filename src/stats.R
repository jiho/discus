#
#  Reformat data, perform statistical analysis and plots
#
#  (c) Copyright 2005-2009 Jean-Olivier Irisson.
#  GNU General Public License
#  Read the file 'src/GNU_GPL.txt' for more information
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


setwd(prefix)


## Read and reformat data
#-----------------------------------------------------------------------

# read corrected tracks
tracks = read.table("tracks.csv", header=TRUE, sep=",")

# set the correct circular class for the positions bearings
# = measured from the north, in degrees, in clockwise direction
tracks$theta = circular(tracks$theta, units="degrees", template="geographics")
tracks$compass = circular(tracks$compass, units="degrees", template="geographics")
tracks$heading = circular(tracks$heading, units="degrees", template="geographics")
# NB: we might need them as regular angles = in radians, measured from zero in counter clockwise direction, because bearings seem to cause issues (in particular with range.circular)

# set the class of times
options("digits.secs" = 1)
tracks$exactDate = as.POSIXct(tracks$exactDate)
tracks$date = as.POSIXct(tracks$date)

# reorganize tracks in a list by [[trackNb]][[original/corrected]]
tracks = llply(split(tracks, tracks$trackNb), function(x){split(x, x$correction)})
nbTracks = length(tracks)


## Statistics and plots
#-----------------------------------------------------------------------

# Compute positions statistics
p = ldply(tracks, function(t, ...){
	pp = ldply(t, function(x, ...){circ.stats(x$theta, x$exactDate, ...)}, ...)
	names(pp)[1] = "correction"
	pp$correction = as.logical(as.character(pp$correction))
	pp[ ! pp$correction, "mean"] = NA
	return(pp)
}, subsampleTime=subsampleTime)
names(p)[1] = "trackNb"
p$kind = "position"

# Compute direction statistics
# compute a speed threshold under which the movement is discarded because it could be in great part du to error of measure
# remove speed which are potentially more than 1/4 of random noise
minSpeed = 0.4
# the min speed is chosen this way:
#	meanErrorInPx * px2cm * 4
# the mean error in pixels is estimated by tracking the same larva several times and comparing the positons recorded. It is usually about 2.5 px.
d = ldply(tracks, function(t, ...){
	# create a filter for speeds
	# NB: it is based on the uncorrected tracks only since the speed are only real in that case
	idx = t["FALSE"][[1]]$speed > minSpeed
	# compute stats only on filtered value
	pp = ldply(t, function(x, idx, ...){
		x = x[!is.na(idx) & idx, ]
		# if there are no speeds, skip the computation of stats
		if (nrow(x) == 0) {
			return(c(mean=NA))
		} else {
			return(circ.stats(x$heading, x$exactDate, ...))
		}
	}, idx=idx, ...)
	names(pp)[1] = "correction"
	pp$correction = as.logical(as.character(pp$correction))
	pp[ ! pp$correction, "mean"] = NA
	return(pp)
}, subsampleTime=1, minSpeed=minSpeed)
names(d)[1] = "trackNb"
d$kind = "direction"

# Display statistical results and write them to file
# TODO improve the display
stats = rbind.fill(p, d)
cat("Statistics:\n")
print(stats)
write.table(stats, file="stats.csv", row.names=FALSE, sep=",")



# Prepare plots
plots = llply(tracks, .fun=function(t, aquariumDiam) {

	# merge the two data.frames
	t = do.call("rbind", t)
	# make nicer labels for correction
	t$correction = factor(t$correction, levels=c(FALSE,TRUE), labels=c("original","corrected"))
	# compute time since start
	t$time = as.numeric(t$date-min(t$date, na.rm=T))

	# prepare a container for plots
	ggplots = list()

	# detect the number of successive images to plot appropriate plots
	# = if there are no successive images (usually because of resampling) there is no point in plotting trajectory or computing speeds
	# we only need one of the two tracks
	x = t[t$correction=="original", ]
	successive = is.na(x$date) + is.na( c(NA, x$date[-nrow(x)]) )
	# successive == 0 when there are successive images
	# we count all those
	successive = sum(successive == 0)


	# Compass readings
	# (for one track only: the compass track is the same)
	compass = ggplot(x) + geom_point(aes(x=compass, y=time, colour=time), alpha=0.5, size=3) + polar() + opts(title="Compass rotation") + scale_y_continuous("", breaks=NA, limits=c(-max(x$time, na.rm=T), max(x$time, na.rm=T))) + opts(axis.text.x=theme_blank())
	# NB: the y scale is so that bearings are spread on the vertical and we can see when the compass goes back and forth
	# the labels are suppressed because there is no actual North there: we actually track the North!
	ggplots = c(ggplots, list(compass))


	# Trajectory
	if (successive > 0) {
		# (plotted only if there are at least 2 successive positions)
		radius = aquariumDiam/2
		traj = ggplot(t) + geom_path(aes(x=x, y=y, colour=time), arrow=arrow(length=unit(0.01,"native")) ) + xlim(-radius,radius) + ylim(-radius,radius) + coord_equal() + facet_grid(~correction) + opts(title="Trajectory")
		# TODO add a circle around
		ggplots = c(ggplots, list(traj))
	}


	# Point positions
	positions = ggplot(t) + geom_point(aes(x=theta, y=1), alpha=0.1, size=4) + scale_y_continuous("", limits=c(0,1.05), breaks=NA) + polar() + opts(title="Positions") + facet_grid(~correction)


	# Rose positions
	pHist = ggplot(t) + geom_bar(aes(x=theta), binwidth=45/4) + polar() + opts(title="Histogram of positions") + facet_grid(~correction)
	# TODO Add mean vector


	# Density positions
	dens = ddply(t,~correction, function(x) {
		d = density.circular(x$theta, na.rm=T, bw=100)
		data.frame(angle=d$x, density=d$y)
	})
	# make all angles positive for ggplot
	dens$angle = (dens$angle+360) %% 360
	# we will plot the density originating from a circle of radius "offset", otherwise it looks funny when it goes down to zero
	offset = 0.5
	dens$offset = offset
	# since the whole y scale will be shifted, we recompute breaks and labels
	labels = pretty(dens$density, 4)
	breaks = labels + offset
	# construct the layer and y scale
	pDens = ggplot(dens) + geom_ribbon(mapping=aes(x=as.numeric(angle), ymin=offset, ymax=density+offset)) + scale_y_continuous("density", limits=c(0, max(dens$density+offset)), breaks=breaks, labels=labels) + polar() + opts(title="Density distribution of positions") + facet_grid(~correction)

	ggplots = c(ggplots, list(positions, pHist, pDens))


	if (successive > 0) {
		# Rose directions
		dHist = ggplot(t) + geom_bar(aes(x=heading), binwidth=45/4) + polar() + opts(title="Histogram of swimming directions") + facet_grid(~correction)


		# Speed distribution
		# plot only for uncorrected tracks (the speeds are NA for the corrected one)
		x = t[t$correction=="original", ]
		# prepare the scale and the base plot
		maxSpeed = 5
		scale_x = scale_x_continuous("Speed (cm/s)", limits=c(0,max(max(x$speed, na.rm=T),maxSpeed)))
		p = ggplot(x, aes(x=speed)) + scale_x
		# add geoms
		sHist = p + geom_histogram(binwidth=0.5) + opts(title="Histogram of swimming speeds (original track)")
		sDens = p + geom_density(fill="grey20", colour=NA) + opts(title="Density distribution of swimming speeds (original track)")


		ggplots = c(ggplots, list(dHist, sHist, sDens))
	}

	return(ggplots)
}, aquariumDiam)


cat("Plotting each track\n")

# Plot to PDF file
for (name in names(tracks)) {
	# reduce the number of hierachy levels to ease plotting
	p = unlist(plots[name], F)
	if (nbTracks > 1) {
		filename = paste("plots-",name,".pdf",sep="")
	} else {
		filename="plots.pdf"
	}
	pdf(file=filename, width=7, height=5, pointsize=10)
	theme_set(theme_gray(10))
	dummy = l_ply(p, print, .progress="text")
	dummy = dev.off()
}

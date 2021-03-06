#
#  Reformat data, perform statistical analysis and plots
#
#  (c) Copyright 2005-2011 J-O Irisson, C Paris
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
if (length(args) !=4) {
	stop("Not enough arguments")
}
prefix = args[1]
aquariumDiam = as.numeric(args[2])
subsampleTime = as.numeric(args[3])
binningAngle = as.numeric(args[4])
# In case we need to call it without the shell script
# prefix="/home/jiho/current_data/1/tmp/"
# aquariumDiam = 40
# subsampleTime = 15
# binningAngle = 5


setwd(prefix)


## Read and reformat data
#-----------------------------------------------------------------------

# read corrected tracks
tracks = read.table("tracks.csv", header=TRUE, sep=",")

# round angles to a given precision (equivalent of binning)
if (binningAngle != 0) {
	tracks$theta = round_any(tracks$theta, binningAngle)
	tracks$heading = round_any(tracks$heading, binningAngle)
}

# set the correct circular class for the positions bearings
# = measured from the north, in degrees, in clockwise direction
tracks$theta = circular(tracks$theta, units="degrees", template="geographics")
tracks$compass = circular(tracks$compass, units="degrees", template="geographics")
tracks$heading = circular(tracks$heading, units="degrees", template="geographics")

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
	pp = ldply(t, function(x, ...){
		# check the function circ.stats in lib_circular_stats.R for more details
		circ.stats(x$theta, x$exactDate, ...)
	}, ...)
	# convert the first column into a boolean telling whether the track is corrected or not
	names(pp)[1] = "correction"
	pp$correction = as.logical(as.character(pp$correction))
	# for uncorrected tracks, suppress the mean angle, which is meaningless (they are not in cardinal reference)
	pp[ ! pp$correction, "mean"] = NA
	return(pp)
}, subsampleTime=subsampleTime)
names(p)[1] = "trackNb"
# set the kind of measurements on which we performed the stats
p$kind = "position"

# Compute direction statistics
# compute a speed threshold under which the movement is discarded because it could be in great part due to error of measure
# remove speed which are potentially more than 1/4 of random noise
minSpeed = 0.4
# the min speed is chosen this way:
#	meanErrorInPx * px2cm * 4
# the mean error in pixels is estimated by tracking the same larva several times and comparing the positons recorded. It is usually about 2.5 px.
d = ldply(tracks, function(t, ...){
	# create a filter for speeds
	# NB: it is based on the uncorrected tracks only since the speed are only real in that case
	idx = t[["FALSE"]]$speed > minSpeed
	# compute stats only on filtered values
	pp = ldply(t, function(x, idx, ...){
		x = x[!is.na(idx) & idx, ]
		if (nrow(x) < 2) {
			# if there are not enough speeds, skip the computation of stats
			return(c(mean=NA))
		} else {
			# else call circ.stats
			return(circ.stats(x$heading, x$exactDate, ...))
		}
	}, idx=idx, ...)
	# similarly to above, remove mean angle for uncorrected tracks
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
# add mention of rounding
stats$bin = binningAngle

cat("Statistics:\n")
print(stats)
write.table(stats, file="stats.csv", row.names=FALSE, sep=",")



# Prepare plots
plots = llply(tracks, .fun=function(t, aquariumDiam) {

	# merge the two data.frames
	t = do.call("rbind", t)
	# make nicer labels for correction (original, corrected instead of TRUE, FALSE)
	t$correction = factor(t$correction, levels=c(FALSE,TRUE), labels=c("original","corrected"))
	# compute time since start, in seconds
	t$time = as.numeric(t$date-min(t$date, na.rm=T))

	# prepare a ggplot container for plots
	ggplots = list()

	# detect the number of successive positions, to plot appropriate plots
	# = if there are no successive images (usually because of resampling) there is no point in plotting trajectories or displaying speeds
	# we only need one of the two tracks
	x = t[t$correction=="original", ]
	successive = is.na(x$date) + is.na( c(NA, x$date[-nrow(x)]) )
	# successive == 0 when there are successive images
	# we count all those
	successive = sum(successive == 0)


	# Compass readings
	# (for one track only: the compass readings are the same in the original and corrected tracks)
	p = ggplot(x) + polar() + opts(title="Compass rotation") +
			geom_point(aes(x=compass, y=time, colour=time), alpha=0.5, size=3) +
			scale_y_continuous("", breaks=NULL, limits=c(-max(x$time, na.rm=T), max(x$time, na.rm=T))) +
			# NB: the y scale is so that bearings are spread on the vertical and we can see when the compass goes back and forth
			opts(axis.text.x=theme_blank())
			# the labels are suppressed because there is no actual North there: we track the North!
	ggplots = c(ggplots, list(compass=p))


	# Trajectory
	# (plotted only if there are at least 2 successive positions)
	if (successive > 0) {
		radius = aquariumDiam/2
		p = ggplot(t) + opts(title="Trajectory") +
			geom_path(aes(x=x, y=y, colour=time), arrow=arrow(length=unit(0.01,"native")) ) +
			xlim(-radius,radius) + ylim(-radius,radius) + coord_equal() +
			facet_grid(~correction)
		ggplots = c(ggplots, list(trajectory=p))
		# TODO add a circle around
	}


	# Point positions
	p = ggplot(t) + polar() + opts(title="Positions") +
		geom_point(aes(x=theta, y=1), alpha=0.1, size=4) +
		scale_y_continuous("", limits=c(0,1.05), breaks=NULL) +
		facet_grid(~correction)
	ggplots = c(ggplots, list(positions = p))


	# Rose positions
	p = ggplot(t) + polar() + opts(title="Histogram of positions") +
		geom_histogram(aes(x=theta), binwidth=45/4) +
		facet_grid(~correction)
	ggplots = c(ggplots, list(position.histogram=p))
	# TODO Add mean vector


	# Density positions
	dens = ddply(t,~correction, function(x) {
		d = density.circular(x$theta, na.rm=T, bw=100)
		data.frame(angle=d$x, density=d$y)
	})
	# scale density to a max of 1
	dens$density = dens$density / max(dens$density, na.rm=T)
	# make all angles positive for ggplot
	dens$angle = (dens$angle+360) %% 360
	# we will plot the density originating from a circle of radius "offset", otherwise it looks funny when it goes down to zero
	offset = 0.5
	dens$offset = offset
	# since the whole y scale will be shifted, we recompute breaks and labels
	labels = c(0,0.5,1)
	breaks = labels + offset
	# construct the layer and y scale
	p = ggplot(dens) + polar() + opts(title="Density distribution of positions") +
		geom_ribbon(mapping=aes(x=as.numeric(angle), ymin=offset, ymax=density+offset)) +
		scale_y_continuous(name="scaled density", breaks=breaks, labels=labels, limits=c(0,1.5)) +
		facet_grid(~correction)
	ggplots = c(ggplots, list(position.density=p))


	if (successive > 0) {
		# Rose directions
		p = ggplot(t) + polar() + opts(title="Histogram of swimming directions") +
			geom_histogram(aes(x=heading), binwidth=45/4) +
			facet_grid(~correction)
		ggplots = c(ggplots, list(direction.histogram=p))


		# Speed distribution
		# plot only for uncorrected tracks (the speeds are NA for the corrected one)
		x = t[t$correction=="original", ]
		# prepare the scale and the base plot
		maxSpeed = 5
		pBase = ggplot(x, aes(x=speed)) +
			scale_x_continuous("Speed (cm/s)", limits=c(0,max(max(x$speed, na.rm=T),maxSpeed)))
		# add geoms
		p = pBase + opts(title="Histogram of swimming speeds (original track)") +
			geom_histogram(binwidth=0.5)
		ggplots = c(ggplots, list(speed.histogram=p))

		if (length(na.omit(x$speed)) > 2) {
			p = pBase + opts(title="Density distribution of swimming speeds (original track)") +
				geom_density(fill="grey20", colour=NA, na.rm=T)
			ggplots = c(ggplots, list(speed.density=p))
		}
	}

	return(ggplots)
}, aquariumDiam)


cat("Plotting each track\n")

# Plot to PDF file
for (name in names(tracks)) {
	# reduce the number of list levels to ease plotting
	p = unlist(plots[name], F)
	# determine the file name(s) for the output PDF file
	if (nbTracks > 1) {
		filename = paste("plots-",name,".pdf",sep="")
	} else {
		filename="plots.pdf"
	}
	# open the PDF file and print the plots in it
	pdf(file=filename, width=7, height=5, pointsize=10)
	# set a theme with smaller fonts and grey background
	theme_set(theme_gray(10))
	dummy = l_ply(p, print, .progress="text")
	# close PDF file
	dummy = dev.off()
}

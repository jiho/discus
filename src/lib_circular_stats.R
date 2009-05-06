#
#		BlueBidule
#
#		Library of functions usefull to handle circular data
#			Conversion functions, statistical tests, plots
#
# (c) Jean-Olivier Irisson 2005-2009
# Released under GNU General Public Licence
# Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

## Trigonometric functions
#-----------------------------------------------------------------------

trig2geo <- function(x)
#
#	Convert object x of class circular (or in trigonometric reference) to bearings
#
#	Bearings are measured clockwise from the vertical in degrees
#	Trigonometric angles are measured counterclockwise from the horizontal in radians
#
{
	require("circular")
	# Cast to circular type
	if (!is.circular(x)) {
		x = circular(x)
	}
	# Proceed to the conversion
	x = conversion.circular(x, units="degrees", template="geographics", modulo="2pi")
	return(x)
}

geo2trig <- function(x)
#
#	Convert object x of class circular (or containing bearings) to trigonometric angles
#
#	Bearings are measured clockwise from the vertical in degrees
#	Trigonometric angles are measured counterclockwise from the horizontal in radians
#
{
	require("circular")
	# Cast to circular type
	if (!is.circular(x)) {
		x = circular(x, units="degrees", template="geographics", modulo="2pi")
	}
	# Proceed to the conversion
	x = conversion.circular(x, units="radians", template="none", modulo="2pi", zero=0, rotation="counter")
	return(x)
}

car2pol <- function (incar, orig=c(0,0))
#
# Translates from cardinal to polar coordinates
#	incar		matrix or data frame with columns [x,y]
#	orig		vector with the x,y coordinates of the origin
# Result: a matrix or data.frame with columns [theta,rho], with theta in radians
#
{
	# Makes the coordinates relative to the origin
	origMat=incar
	origMat[,1]=orig[1]
	origMat[,2]=orig[2]
	incar=incar-origMat

	# Initiate inpol
	inpol=incar
	inpol[,]=NA

	# Calculate the angles
	inpol[,1]=atan2(incar[,2],incar[,1])
	inpol[,1]=(inpol[,1]+2*pi)%%(2*pi)
	# Calculate the norms
	inpol[,2]=sqrt(incar[,1]^2+incar[,2]^2)

	# Change column names
	names(inpol)=c("theta","rho")

	# Convert to class circular
	require("circular")
	inpol$theta = circular(inpol$theta)

	return(inpol)
}

pol2car <- function (inpol, orig=c(0,0))
#
# Translates from polar to cardinal coordinates
#	inpol		a matrix or data.frame with columns [theta,rho], with theta of class circular or in trigonometric reference
#	orig		vector with the x,y coordinates of the origin
# Result: a matrix or data.frame with columns [x,y]
#
{
	# Initiate incar
	incar=inpol
	incar[,]=NA

	# Make sure angles are in the right reference
	if (!is.circular(inpol[,1])) {
		inpol[,1] = circular(inpol[,1])
	}
	inpol[,1] = geo2trig(inpol[,1])

	# Compute cartesian coordinates
	incar[,1]=inpol[,2]*cos(inpol[,1])
	incar[,2]=inpol[,2]*sin(inpol[,1])

	# Make the coordinates relative to the origin
	origMat=incar
	origMat[,1]=orig[1]
	origMat[,2]=orig[2]
	incar=incar+origMat

	# Change column names
	names(incar)=c("x","y")

	return(incar)
}


## Manipulation of angles
#------------------------------------------------------------------------------

approx.circular <- function(x, angles, xout, ...)
#
# "Linearly" interpolates angles along a circle
#	x			coordinates/reference of the angles to be interpolated
#	angles	angles to be interpolated, of class circular or in trigonometric reference
#	xout		coordinates/reference where the interpolation should take place
#	...		passed to approx
#
{
	# Get circular characteristics of the angles object if it is of class circular
	if (is.circular(angles)) {
		a = attributes(angles)$circularp
	}

	# Convert angles to cardinal coordinates
	incar = pol2car(data.frame(angles,1))

	# Interpolate each cardinal component independently
	xInterp = approx(x, incar[,1], xout, ...)
	yInterp = approx(x, incar[,2], xout, ...)

	# Convert back in polar coordinates
	inpol = car2pol(data.frame(xInterp$y, yInterp$y))

	# Convert the angles to the same circular attributes
	if (is.circular(angles)) {
		inpol$theta = conversion.circular(inpol$theta, type=a$type, units=a$units, template=a$template, modulo=a$modulo, zero=a$zero, rotation=a$rotation)
	}

	return(list(x=xInterp$x, y=inpol$theta))
}


## Statistical functions
#-----------------------------------------------------------------------

circ.stats <- function(t, subsampleTime)
#
#	Descriptive statistics and Rayleigh test
#
# 	t						a track record
#	subsampleTime		interval (in seconds) at which to resample data to assume the points to be independant. If the data is aleady sampled at an interval >= subsample.interval then simple statistics are computed. Otherwise, the data provided is  "bootstrapped"
#
#	Value
#	a data.frame with columns
#		n			sample size
#		mean		mean angle
#		variance, sd	angular variance, standard deviation
#		R			Rayleigh R
#		p.value	Rayleigh's test p-value
#
{
	# remove NAs. we don't have a use for them here
	t = t[!is.na(t$theta),]

	# sample size
	n = nrow(t)

	# mean angle
	mean = mean.circular(t$theta)

	# From this point we do different things depending whether we have a sample of independent data or not:
	# - if mean time between images is long, then images were subsampled and the records are independent already
	# - if mean time between images is short, then records are not independant and need to be subsampled

	if ( mean(diff(t$exactDate)) > subsampleTime ) {
		# we have independant records already, just perform simple tests

		# rayleigh test
		rayleigh = rayleigh.test(t$theta)
		R = rayleigh$statistic
		p = rayleigh$p.value

		# angular variance ~ variance
		#  = (1-r)
		# NB: Batschelet, 1981. Circular Statistics in Biology. p. 34 adds a multiplication by 2 compared to this formula
		variance = 1 - R
		# variance = var.circular(angles)

		# # angular deviation ~ standard deviation
		# # = sqrt( (1-r) )
		# sd = sqrt(variance)

		return(data.frame(n, mean, resample.lag=1, variance, R, p.value=p))

	} else {
		# the samples are not independant, so we resample independant samples with intervals of subsampleTime

		# the the validity of the subsampling interval
		if (n/subsampleTime < 10) {
			warning("\n  Subsampling will result in less than 10 records.\n  You are advised to decrease it with -ssub.\n", immediate.=TRUE, call.=FALSE)

			if (subsampleTime > n) {
				stop("\n  Subsampling interval larger than number of records.\n  Decrease it with the option -ssub.\n", call.=FALSE)
			}
		}



		# time of the last record, we can't go beyond that
		lastRecord = t$exactDate[n]

		# storage for test results
		stats = list()

		# loop on succesive lags until we reach the the first sample
		i=1
		startTime = t$exactDate[1]
		while ( startTime < t$exactDate[1]+subsampleTime ) {
			# generate time coordinates
			startTime = t$exactDate[i]
			times = seq(startTime, lastRecord, by=subsampleTime)
			# find the indexes of these times
			# (oh I love this small which.closest function ;) )
			idx = round(approx(t$exactDate,1:n,times)$y)

			# get the subsample
			angles = t$theta[idx]

			# perform rayleigh test on it
			rayleigh = rayleigh.test(angles)
			# and store results
			stats = rbind(stats, data.frame(R=rayleigh$statistic, p.value=rayleigh$p.value, mean=mean.circular(angles)))

			# increment lag
			i = i+1
		}

		# compute mean statistic and p-value
		means = mean(stats)
		variance = var.circular(stats$mean)


		return(data.frame(n, mean, resample.lag=subsampleTime, variance, R=means[1], p.value = means[2]))
	}
}


## ggplot2 functions
#------------------------------------------------------------------------------

scale_x_circular <- function(template=c("geographics", "none"))
#
#	Set the x scale appropriately for the given template
#	template		"geographics" (for bearings) or "none" (for trigonometric angles)
#
{
	template = match.arg(template)
	if (template == "geographics") {
		# set the scale for compass bearings
		scale = scale_x_continuous( limits=c(0,360),
		                    breaks=seq(0,360-1,by=45),
		                    labels=c("N","N-E","E","S-E","S","S-W","W","N-W"))
	} else {
		# set the scale for trigonometric angles
		scale = scale_x_continuous( limits=c(0,2*pi),
		                    breaks=seq(0, 2*pi-0.001 , by=pi/2),
		                    labels=c("0", expression(frac(pi,2)), expression(pi), expression(frac(3*pi,2))))
	}
	return(scale)
}

polar <- function(...)
#
#	Set polar coordinates
#	...	passed to scale_x_circular to set the template
#
{
	list(coord_polar(theta="x"), scale_x_circular(...))
}

geom_density_circular <- function(x, ...)
#
#	Use density.circular to compute density and return a ggplot layer and a scale
#	x		an object of class circular
#	...	passed to density.circular
{
	# safety test
	if (!is.circular(x)) {
		stop("geom_density_circular needs data of type circular")
	}

	# conserve circular attributes
	xp = circularp(x)
	if (xp$units == "degrees") {
		from = circular(0)
		to = circular(360)
	} else {
		from = circular(0)
		to = circular(2*pi)
	}
	circularp(from) <- xp
	circularp(to) <- xp

	# we use the density function of the package circular so we compute the density manually
	dens = density.circular(x, from=from, to=to, ...)

	# we will plot the density originating from a circle of radius "offset", otherwise it looks funny when it goes down to zero
	offset=0.5

	# convert it to data.frame
	dens = data.frame(angle=as.numeric(dens$x), density=dens$y, offset=offset)

	# since the whole y scale will be shifted, we recompute breaks and labels
	labels = pretty(dens$density, 4)
	breaks = labels + offset

	# construct the layer and y scale
	return( list(geom_ribbon(data=dens, mapping=aes(x=angle, ymin=offset, ymax=density+offset)),
	             scale_y_continuous("density", limits=c(0, max(dens$density+offset)), breaks=breaks, labels=labels)) )
}

#
#   Library of R functions to read and compute image time from EXIF data
#
#  (c) Copyright 2009 Jean-Olivier Irisson.
#  GNU General Public License
#  Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------------

# Global test for the existence of exiftool
exiftool = system("which exiftool",intern=TRUE)
if (length(exiftool) == 0) {
	stop("Please install exiftool http://www.sno.phy.queensu.ca/~phil/exiftool/\n")
}


img <- function(n, imageSource)
#
# Return the filename of an image assuming the path is:
#		imageSource/n.jpg
#	n					image number
#	imageSource		directory where to find the image
#
{
	paste(imageSource,"/",n,".jpg",sep="")
}

image.time <- function(img)
#
#	Extract the time from the exif data of an image
#	img			full file name of the image
#
{
	dateTime = system(paste("exiftool -T -CreateDate", paste(img, collapse=" ")), intern=TRUE)
	dateTime = as.POSIXct(strptime(dateTime, format="%Y:%m:%d %H:%M:%S", tz="GMT"))
	return(dateTime)
}

time.lapse.interval <-function(images)
#
#	Compute the mean time lapse in seconds between the provided images
#	images		vector of full images names
#
{
	if ( all( file.exists(images) ) ) {
		# detect image times
		times = image.time(images)
		# compute intervals in seconds
		intervals = diff(times)
		units(intervals) = "secs"
		# compute mean interval
		interval = as.integer( round( mean(intervals) ) )
		return(interval)
	} else {
		warning( paste("\nSome images not found. Impossible to compute time lapse interval.\n",paste(images, collapse="\n"), sep=""), immediate. = FALSE)
		return(NULL)
	}
}

find.image.by.time <- function(target, n=1, imageSource)
#
#	Find the image which time is closest to a target time
#	target			target time (a POSIXct variable)
#	n					inital guess at the image number (name)
#	imageSource		directory where to find the images
#
{
	# test for the existence of the start image
	imgStart = img(n, imageSource)
	if ( ! file.exists(imgStart) ) {
		return(NULL)
	}

	# compute interval (in seconds) between successive images
	interval = time.lapse.interval(img(n:(n+20), imageSource))

	# compute the time difference between the time of the inital guess image and the target time, in seconds. Divided by the interval between images it gives  the number of images that we should shift by to find the image corresponding to the target time
	shift = as.integer( difftime(target, image.time(imgStart), units="secs") / interval )

	# recursively shift until the we find the image corresponding to the target time
	count = 0
	while ( ! shift %in% c(-1,0,1) ) {
		# count the number of iterations in the loop
		count = count + 1

		# shift image number
		n = n + shift

		newImg = img(n, imageSource)

		# if the file exists, then check its time difference with the target
		# otherwise, it means we ran out of files in the current directory and we need to fall back on the last file available
		if (file.exists(newImg)) {
			shift = as.integer( difftime(target, image.time(newImg), units="secs") / interval )
			fallback = FALSE
		} else {
			while(!file.exists(newImg)) {
				n = n - 1
				newImg = img(n, imageSource)
			}
			fallback = TRUE
			break
		}
	}

	# return the number of the target image
	return(list(n=n, fallback=fallback, interval=interval, count=count))
}

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


image.time <- function(img)
#
#	Extract the time from the exif data of an image
#	img			full path of the image
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

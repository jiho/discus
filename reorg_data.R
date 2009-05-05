#
#	Gather and split data sources per deployment
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#-----------------------------------------------------------------------------


image.time <- function(img)
#
#	Extract the time from the exif data of an image
#	img				file name of the image
#	imageSource		directory where to find the images
#
{
	dateTime = system(paste("exiftool -T -CreateDate", img), intern=TRUE)
	dateTime = as.POSIXct(strptime(dateTime, format="%Y:%m:%d %H:%M:%S", tz="GMT"))
	return(dateTime)
}

img <- function(n, imageSource)
#
# Compute the filename of an image given its number
#	n					image number
#	imageSource		directory where to find the image
#
{
	paste(imageSource,"/",n,".jpg",sep="")
}

find.image.by.time <- function(target, n=1, imageSource)
#
#	Find the image which time is closest to a target time
#	target			target time (a POSIXct variable)
#	n					inital guess at the image number (name)
#	imageSource		directory where to find the images
#
{
	# compute interval (in seconds) between successive images
	# NB: comput that approximately and on 20 images because the interval is not constant
	imgStart = img(n, imageSource)
	imgEnd = img(n+20, imageSource)
	if ( all( file.exists(imgStart, imgEnd) ) ) {
		interval = as.integer( round( difftime( image.time(imgEnd),
	                                           image.time(imgStart),
	                                           units="secs")
	                                 / 20 ) )
	} else {
		warning("\nImpossible to compute time lapse interval. Start image:\n   ",
		    imgStart,
		    "\nnot found or too close to the end.\n", immediate. = FALSE)
		return(NULL)
	}

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


#------------------------------------------------------------------------------


prefix = "/media/data/DISC-One_Tree_Island/DISC"

cat("  read logs\n")
# read deployment log
log = read.table(paste(prefix,"/log-disc_deployment.csv",sep=""), header=TRUE, sep=",", as.is=TRUE)
log$dateTime = paste(log$date, log$timeIn)
log$dateTime = as.POSIXct(strptime(log$dateTime, format="%Y-%m-%d %H:%M", tz="GMT"))
# NB: the timezone is not GMT but we use that as a cross platform reference for a common time specification.
# head(log)

# read start time of the day log
startLog = read.table(paste(prefix,"/log-camera_start_time.csv", sep=""), header=TRUE, sep=",", as.is=TRUE)
startLog$dateTime = paste(startLog$date, startLog$startTime)
startLog$dateTime = as.POSIXct(strptime(startLog$dateTime, format="%Y-%m-%d %H:%M:%S", tz="GMT"))

# time constants
initialLag = 5    # time to wait after the start of deployment [minute]
duration = 20     # duration of the deployment (including initialLag) [minute]
# the time range is extended by a few seconds to be sure to select everything [sec]
fuzPic = 10 		# for pictures (sampling period = 2 s)
fuzGps = 60 		# for gps (sampling period = 60 s)
fuzCtd = 20 		# for ctd (sampling period = 10 s)
fuzCompass = 20 	# for compass (sampling period = 10 s)


# for each deployment (row extract the corresponding data)
for (i in 1:nrow(log)) {

	# select current deployment
	cLog = log[i,]

	# most data is initially organized by day, so all the initial reading of data is to be done by day.
	# so we start by detecting whether the current deployment is on a new day or not, and perform appropriate actions if it is.
	if (any(i == 1, log[i,"date"] != log[i-1,"date"]) ) {
		cat("  --", log[i,"date"], ":")

		# initialize variables
		ctdOK = FALSE
		gpsOK = FALSE
		compassOK = FALSE

		# identify the directory containing data for this day
		dataSource = paste(prefix, "/", cLog$date, sep="")

		cat(" collect all images")
		# collect all images into one temporary directory
		# start by erasing previous directory
		if ( exists("imageSource") ) {
			if( file.exists(imageSource) ) {
				system("rm -Rf imageSource")
			}
		}
		# create the new temp directory
		imageSource = system(paste("mktemp -d -p", prefix), intern=TRUE)
		# collect all images for today in it
		system(paste("
			count=1;
			# for each picture
			find ", dataSource,"/DCIM/ -name 'DSC*.JPG' | sort | while read file;
			do
				# create a hard link in the destination directory
				ln $file ", imageSource,"/$count.jpg;

				count=$(echo $count+1 | bc);
			done;",
			sep=""))

		# later in the loop, when we determine the images associated with the current deployment, we start with a guess of where the first image is. Here we set it to 1 as this is new day
		startImage = endImage = 1

		cat(", read data:")
		# get CTD data
		ctdLog = paste(dataSource,"/ctd_log.dat",sep="")
		if (file.exists(ctdLog)) {
			cat(" ctd")
			ctdOK = TRUE

			# read ctd log
			ctd = read.table(ctdLog, header=F, sep="\t", as.is=TRUE, skip=19, col.names=c("record","date","temperature","depth","salinity"))

			# convert time to POSIX class
			ctd$date = as.POSIXct(strptime(ctd$date, format="%d-%m-%y %H:%M:%S", tz="GMT"))
		}

		# get GPS data
		gpsLog = paste(dataSource,"/gps_log.csv", sep="")
		if (file.exists(gpsLog)) {
			cat(" gps")
			gpsOK = TRUE

			# read gps log
			gps = read.table(gpsLog, sep=",", header = TRUE, as.is=T)

			# convert time to POSIX class
			gps$Date = as.POSIXct(strptime(gps$Date, format="%m/%d/%Y %H:%M", tz="GMT"))

			# re-organize data.frame
			gps = data.frame(date=gps$Date, lat=gps$Latitude, lon=gps$Longitude, signal=gps$Signal)
		}

		# get COMPASS data
		compassLog = paste(dataSource,"/compass_log.csv",sep="")
		if (file.exists(compassLog)) {
			cat(" compass")
			compassOK=TRUE

			# read compass data
			compass = read.table(compassLog, header=TRUE, sep=",", as.is=TRUE)

			# convert time stamp into actual time
			startOfDay = startLog[startLog$date == cLog$date, "dateTime"]
			compass$date = startOfDay + compass$Timestamp
		}

		cat("\n")

	}

	# display current deloyment number
	cat(sprintf("%5i",cLog$deployNb))

	# determine start and end time for this deployment
	startTime = cLog$dateTime + initialLag*60
	endTime = cLog$dateTime + duration*60

	# create output directory
	dataDestination = paste(prefix, "/deployments/", cLog$deployNb, sep="")
	system(paste("mkdir -p", dataDestination))


	## IMAGES
	# find start image for this deployment
	startList = find.image.by.time(startTime-fuzPic, endImage+1, imageSource)
	if (!is.null(startList)) {
		# if we can find a start image
		startImage = startList$n
		cat("    imgs ", sprintf("%5i",startImage), " (", startList$count,")", sep="")
		# if the image is a fallback image (the last of the current directory) then cycle to the next deployment because we don't have anything to extract for this one
		if (startList$fallback) {
			cat("*\n")
			next
		}
	} else {
		# if we can't find any we cycle
		cat("*\n")
		next
	}

	# do the same for the end image
	endList = find.image.by.time(endTime+fuzPic, startImage, imageSource)
	endImage = endList$n
	cat(" -> ", sprintf("%5i", endImage), " (", endList$count,")", sep="")
	if (endList$fallback) {
		cat("*")
	}

	# check the validity of this image range
	# compute the total time span that images currently selected represent, in seconds
	timeSpan = (endImage - startImage) * startList$interval
	cat(" =",format(timeSpan/60, digits=3),"min")

	# check that the time span is compatible with deployment duration
	theorSpan = (duration - initialLag) * 60
	if (abs(theorSpan - timeSpan) > 3 * 60) {
		cat(" ** Not enough images **\n")
		next
	}

	# compute the array of images of interest
	cImages = paste(imageSource, "/", seq(startImage, endImage), ".jpg", sep="", collapse=" ")

	# move images to destination
	system(paste("mv", cImages, dataDestination))


	## CTD
	if (ctdOK) {
		# extract relevant CTD data
		cCtd = ctd[ctd$date > startTime-fuzCtd & ctd$date < endTime+fuzCtd, ]

		# write the CTD record with the rest of the data
		if (nrow(cCtd) > 0) {
			write.table(cCtd, paste(dataDestination, "/ctd_log.csv", sep=""), row.names=FALSE, sep=",")
			cat("  +ctd")
		}
	}


	## GPS
	if (gpsOK) {
		# extract relevant gps data
		# NB: gps data is only taken every minute, so we extract more widely, increasing the range by 60 seconds exactly
		cGps = gps[gps$date > (startTime-fuzGps) & gps$date < (endTime+fuzGps), ]

		# write the CTD record with the rest of the data
		if (nrow(cGps) > 0) {
			write.table(cGps, paste(dataDestination, "/gps_log.csv", sep=""), row.names=FALSE, sep=",")
			cat("  +gps")
		}
	}


	## COMPASS
	if (compassOK) {

		# extract relevant compass data
		cCompass = compass[compass$date > startTime-fuzCompass & compass$date < endTime+fuzCompass, ]

		if (nrow(cCompass) > 0) {
			# wite the compass information
			names(cCompass) = tolower(names(cCompass))
			write.table(cCompass, paste(dataDestination, "/compass_log.csv", sep=""), row.names=FALSE, sep=",")
			cat("  +compass")
		}
	}

	cat("\n")
}

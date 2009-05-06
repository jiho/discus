#
#	Gather and split data sources per deployment
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#-----------------------------------------------------------------------------

# Directory where the raw daily logs are stored
prefix = "/media/data/DISC-Lizard-Nov_Dec_08/DISC"

# get some functions to deal with time extracted from XIF data
source("src/lib_image_time.R")


cat("  read logs\n")
# read deployment log
log = read.table(paste(prefix,"/log-disc_deployment.csv",sep=""), header=TRUE, sep=",", as.is=TRUE)
log$dateTime = paste(log$date, log$timeIn)
log$dateTime = as.POSIXct(strptime(log$dateTime, format="%Y-%m-%d %H:%M", tz="GMT"))
# NB: the timezone is not GMT but we use that as a cross platform reference for a common time specification.
# head(log)

# # read start time of the day log
# startLog = read.table(paste(prefix,"/log-camera_start_time.csv", sep=""), header=TRUE, sep=",", as.is=TRUE)
# startLog$dateTime = paste(startLog$date, startLog$startTime)
# startLog$dateTime = as.POSIXct(strptime(startLog$dateTime, format="%Y-%m-%d %H:%M:%S", tz="GMT"))

# time constants
initialLag = 5    # time to wait after the start of deployment [minute]
duration = 20     # duration of the deployment (including initialLag) [minute]
# the time range is extended by a few seconds to be sure to select everything [sec]
fuzPic = 10 		# for pictures (sampling period = 1-2 s)
fuzGps = 60 		# for gps (sampling period = 60 s)
fuzCtd = 20 		# for ctd (sampling period = 10 s)
fuzCompass = 20 	# for compass (sampling period = 10 s)

# Possibly restrict to only a few deployments
# log = log[log$date %in% c("2008-12-06","2008-12-07","2008-12-08"), ]
log = log[log$deployNb %in% 145, ]

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
			sep="")
		)

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

			# deduce the start time of the day as:
			#     time of the first picture - camera delay after startup (~5 sec)
			startOfDay = image.time(paste(imageSource,"/1.jpg", sep=""))

			# convert time stamp into actual time
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
			# write the compass information
			names(cCompass) = tolower(names(cCompass))
			write.table(cCompass, paste(dataDestination, "/compass_log.csv", sep=""), row.names=FALSE, sep=",")
			cat("  +compass")
		}
	}

	cat("\n")
}

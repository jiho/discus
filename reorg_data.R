#
#	Gather and split data sources per deployment
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#-----------------------------------------------------------------------------


image.time <- function(n, imageSource)
#
#	Extract the time from the exif data of an image
#	n					image number (name)
#	imageSource		directory where to find the images
#
{
	img = paste(imageSource,"/",n,".jpg",sep="")
	dateTime = system(paste("exiftool -T -CreateDate", img), intern=TRUE)
	dateTime = as.POSIXct(strptime(dateTime, format="%Y:%m:%d %H:%M:%S"))
	return(dateTime)
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
	interval = as.integer( round( difftime( image.time(n+20, imageSource),
                                           image.time(n   , imageSource),
                                           units="secs")
                                 / 20 ) )

	# compute the time difference between the time of the inital guess image and the target time, in seconds. Divided by the interval between images it gives  the number of images that we should shift by to find the image corresponding to the target time
	shift = as.integer( difftime(target, image.time(n, imageSource), units="secs") / interval )

	# recursively shift until the we find the image corresponding to the target time
	while ( ! shift %in% c(-1,0,1) ) {
		n = n + shift
		shift = as.integer( difftime(target, image.time(n, imageSource), units="secs") / interval )
	}

	# return the number of the target image
	return(n)
}


#------------------------------------------------------------------------------


prefix = "../Lizard_Island/data/"

# read deployment log
log = read.table(paste(prefix,"data_log.csv",sep=""), header=TRUE, sep=",", as.is=TRUE)
log$dateTime = paste(log$date, log$timeIn)
log$dateTime = as.POSIXct(strptime(log$dateTime, format="%Y-%m-%d %H:%M"))
# head(log)

# read start time of the day log
startLog = read.table(paste(prefix,"start_time_log.csv", sep=""), header=TRUE, sep=",", as.is=TRUE)
startLog$dateTime = paste(startLog$date, startLog$startTime)
startLog$dateTime = as.POSIXct(strptime(startLog$dateTime, format="%Y-%m-%d %H:%M:%S"))

# time constants
initialLag = 5    # time to wait after the start of deployment [minute]
duration = 20     # duration of the deployment (including initialLag) [minute]
fuzzy = 10        # the time range is extended by this amount to select the data with a bit more fuzziness [sec]

log = log[log$date=="2008-11-28",]

# for each deployment (row extract the corresponding data)
for (i in 1:nrow(log)) {

	cat(i,"\n")

	# select current deployment
	cLog = log[i,]

	# most data is initially organized by day, so all the initial reading of data is to be done by day.
	# so we start by detecting whether the current deployment is on a new day or not, and perform appropriate actions if it is.
	if (any(i == 1, log[i,"date"] != log[i-1,"date"]) ) {
		# initialize variables
		ctdOK = FALSE
		gpsOK = FALSE
		compassOK = FALSE

		# identify the directory containing data for this day
		dataSource = paste(prefix, "/DISC/", cLog$date, sep="")

		# to determine the IMAGES associated with current deployment, we start with a guess of where the first image is. set it to 1 for this new day
		imageSource = paste(dataSource, "/DCIM-all/", sep="")
		startImage = endImage = 1

		# get CTD data
		ctdLog = paste(dataSource,"/ctd_log.dat",sep="")
		if (file.exists(ctdLog)) {
			ctdOK = TRUE

			# read ctd log
			ctd = read.table(ctdLog, header=F, sep="\t", as.is=TRUE, skip=19, col.names=c("record","date","temperature","depth","salinity"))

			# convert time to POSIX class
			ctd$date = as.POSIXct(strptime(ctd$date, format="%d-%m-%y %H:%M:%S"))
		}

		# get GPS data
		gpsLog = paste(dataSource,"/ctd_log.csv", sep="")
		if (file.exists(gpsLog)) {
			gpsOK = TRUE

			# read gps log
			gps = read.table(gpsLog, sep=",", header = TRUE, as.is=T)

			# convert time to POSIX class
			gps$Date = as.POSIXct(strptime(gps$Date, format="%d/%m/%Y %H:%M"))

			# re-organize data.frame
			gps = data.frame(date=gps$Date, lat=gps$Latitude, lon=gps$Longitude, signal=gps$Signal)

		}

		# get COMPASS data
		compassLog = paste(dataSource,"/compass_log.csv",sep="")
		if (file.exists(compassLog)) {
			compassOK=TRUE

			# read compass data
			compass = read.table(compassLog, header=TRUE, sep=",", as.is=TRUE)

			# convert time stamp into actual time
			startOfDay = startLog[startLog$date == cLog$date, "dateTime"]
			compass$date = startOfDay + compass$Timestamp
		}

	}


	# determine start and end time for this deployment
	startTime = cLog$dateTime + initialLag*60 - fuzzy
	endTime = cLog$dateTime + duration*60 + fuzzy

	# create output directory
	dataDestination = paste(prefix, "/DISC-sorted/", cLog$deployId, sep="")
	system(paste("mkdir -p", dataDestination))


	## IMAGES
	# find start and end image for this deployment
	startImage = find.image.by.time(startTime, endImage+1, imageSource)
	endImage = find.image.by.time(endTime, startImage, imageSource)
	# TODO implement a check on the number of images = detect the lag between pictures and check that the total number of images is compatible with the total duration

	# compute the array of images of interest
	cImages = paste(imageSource, seq(startImage, endImage), ".jpg", sep="", collapse=" ")

	# move images to destination
	system(paste("mv", cImages, dataDestination))


	## CTD
	if (ctdOK) {
		# extract relevant CTD data
		cCtd = ctd[ctd$date > startTime & ctd$date < endTime, ]

		# write the CTD record with the rest of the data
		if (nrow(cCtd) > 0) {
			write.table(cCtd, paste(dataDestination, "/ctd_log.csv", sep=""), row.names=FALSE, sep=",")
		}
	}


	## GPS
	if (gpsOK) {
		# extract relevant gps data
		# NB: gps data is only taken every minute, so we extract more widely, increasing the range by 60 seconds exactly
		cGps = gps[gps$date > (startTime+fuzzy-60) & gps$date < (endTime-fuzzy+60), ]

		# write the CTD record with the rest of the data
		if (nrow(cGps) > 0) {
			write.table(cGps, paste(dataDestination, "/gps_log.csv", sep=""), row.names=FALSE, sep=",")
		}
	}


	## COMPASS
	if (compassOK) {

		# extract relevant compass data
		cCompass = compass[compass$date > startTime & compass$date < endTime, ]

		if (nrow(cCompass) > 0) {
			# wite the compass information
			names(cCompass) = tolower(names(cCompass))
			write.table(cCompass, paste(dataDestination, "/compass_log.csv", sep=""), row.names=FALSE, sep=",")
		}
	}

}

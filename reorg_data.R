#
#	Gather and split data sources per deployment
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#-----------------------------------------------------------------------------

prefix = "../Lizard_Island/data/"

# read data
log = read.table(paste(prefix,"data_log.csv",sep=""), header=TRUE, sep=",", as.is=TRUE)
log$dateTime = paste(log$date, log$timeIn)
log$dateTime = as.POSIXct(strptime(log$dateTime, format="%Y-%m-%d %H:%M"))
# head(log)
startLog = read.table(paste(prefix,"start_time_log.csv", sep=""), header=TRUE, sep=",", as.is=TRUE)
startLog$dateTime = paste(startLog$date, startLog$startTime)
startLog$dateTime = as.POSIXct(strptime(startLog$dateTime, format="%Y-%m-%d %H:%M:%S"))
# TODO organize the fetching of data per day, since it is the base unit of data collection (one CTD, GPS etc. file per day)

log = log[log$date=="2008-11-28",]

for (i in 1:nrow(log)) {
	cLog = log[i,]
}

# determine start and end time for this deployment
initialLag = 5    # time to wait after the start of deployment [minute]
duration = 20     # duration of the deployment (including initialLag) [minute]
fuzzy = 10        # the time range is extended by this amount to select the data with a bit more fuzziness [sec]
startTime = cLog$dateTime + initialLag*60 - 10
endTime = cLog$dateTime + duration*60 + 10

# identify working directories
dataSource = paste(prefix, "/DISC/", cLog$date, sep="")
dataDestination = paste(prefix, "/DISC-sorted/", cLog$deployId, sep="")
# create output directory
system(paste("mkdir -p", dataDestination))


## IMAGES
# get list of images
allImages = system(paste("ls ", dataSource,"/DCIM-all/", sep=""), intern=TRUE)
allImages = sub(".jpg","",allImages)
options(digits.sec=2)
allTimes = as.POSIXct(strptime(allImages, format="%Y-%m-%d_%H-%M-%OS"))
head(allTimes)

# select images relevant to this deployment, by time
cTimes = allTimes[allTimes > startTime & allTimes < endTime]
cImages = paste(dataSource, "/DCIM-all/", format(cTimes, format="%Y-%m-%d_%H-%M-%OS2"), ".jpg", sep="", collapse=" ")
# TODO implement a check on the length of cTimes = detect the lag between pictures and check that the total number of images is compatible with the total duration

# move images to destination
system(paste("mv", cImages, dataDestination))


## CTD
ctdLog = paste(dataSource,"/ctd_log.dat",sep="")
if (file.exists(ctdLog)) {

	# get CTD data
	allCtd = read.table(ctdLog, header=F, sep="\t", as.is=TRUE, skip=19, col.names=c("record","date","temperature","depth","salinity"))
	allCtd$date = as.POSIXct(strptime(allCtd$date, format="%d-%m-%y %H:%M:%S"))

	# extract relevant CTD data
	cCtd = allCtd[allCtd$date > startTime & allCtd$date < endTime, ]

	# write the CTD record with the rest of the data
	if (nrow(cCtd > 0)) {
		write.table(cCtd, paste(dataDestination, "/ctd_log.csv", sep=""), row.names=FALSE, sep=",")		
	}
}

## GPS
# get GPS data
# gpsLog = paste(dataSource,"/ctd_log.dat",sep="")


## COMPASS
compassLog = paste(dataSource,"/compass_log.csv",sep="")
if (file.exists(compassLog)) {

	# get compass data
	allCompass = read.table(compassLog, header=TRUE, sep=",", as.is=TRUE)
	
	# convert time stamp into actual time
	startOfDay = startLog[startLog$date == cLog$date, "dateTime"]
	allCompass$date = startOfDay + allCompass$Timestamp
	
	# extract relevant compass data
	cCompass = allCompass[allCompass$date > startTime & allCompass$date < endTime, ]

	# wite the compass information
	names(cCompass) = tolower(names(cCompass))
	write.table(cCompass, paste(dataDestination, "/compass_log.csv", sep=""), row.names=FALSE, sep=",")
}

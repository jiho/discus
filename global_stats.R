#
#	Study the orientation of tracked larvar globally
#
#
# (c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#------------------------------------------------------------------------------

prefix = "../current_data"
logPrefix = "/media/data/DISC-Lizard-Nov_Dec_08/DISC"

# detect available deployments
deployments = as.numeric(system(paste("ls -1 ", prefix," | sort -n"), intern=T))

# resrict to those having stats done
deployments = deployments[file.exists(paste(prefix, deployments, "stats.csv", sep="/"))]
# remove some problematic ones (issues with compass)
deployments = deployments[ ! deployments %in% 108:111]


# read data log
log = read.table(paste(logPrefix,"log-disc_deployment.csv",sep="/"), header=TRUE, sep=",", as.is=T)
log = log[log$deployNb %in% deployments,]
# clean it a bit
log = log[, !names(log) %in% c("latInDeg", "LatInMin", "lonInDeg", "lonInMin", "latOutDeg", "latOutMin", "", "lonOutDeg", "lonOutMin", "process", "comments")]
log$nbFish = cut(log$nbFish, breaks=c(0,2,20), labels=c("individual","school"))


# collect stats
stats = data.frame()
for (d in deployments) {
	cStats = read.table(paste(prefix, d, "stats.csv", sep="/"), header=TRUE, sep=",", as.is=TRUE)
	cStats$deployNb = d
	stats = rbind(stats, cStats)
}
stats = stats[stats$kind=="position",]
# assign classes
# library("circular")
# s$mean = circular(s$mean, units="degrees", template="geographics")
stats$mean = (stats$mean+360) %% 360


# merge all information
stats = merge(stats, log)


# keep only corrected positions
s = stats[stats$correction, ]

# how many in each
ddply(s, .(nbFish), nrow)


# plot mean vectors
library("ggplot2")
source("src/lib_circular_stats.R")

yscale = scale_y_continuous("",limits=c(0,1.1), breaks=NA)

ggplot(s, aes(x=mean)) + geom_point(aes(y=1, colour=nbFish), size=4, alpha=0.5) + polar() + yscale

ggplot(s, aes(x=mean)) + geom_point(aes(y=1, colour=nbFish, shape=p.value<0.05), size=4, alpha=0.5) + polar() + yscale

p1 = ggplot(s, aes(x=mean)) + geom_point(aes(y=1, shape=p.value<0.05), size=3, alpha=0.5) + polar() + yscale +facet_grid(nbFish~.)
p1

# population directionality test
# keep only directional larvae
ss = s[s$p.value<0.05,]
# compute mean vector and do directionality test
ddply(ss, .(nbFish), function(x) {
	x$mean = circular(x$mean, units="degrees", template="geographics")
	mean = (mean.circular(x$mean)+360)%%360
	r=rayleigh.test(x$mean)
	return(data.frame(mean=mean, R=r$statistic, p.value=r$p.value))
})


# test for real orientation
orient = ddply(stats, .(deployNb), function(x) {return(c(orientation=x[x$correction,]$variance < x[!x$correction,]$variance))})
# and plot it
s = merge(s, orient)
p2 = ggplot(s, aes(x=mean)) + geom_point(aes(y=1, colour=orientation), size=3, alpha=0.5) + polar() + yscale + facet_grid(nbFish~.)
p2

# plot depending on time of day
s$hour = as.numeric(substr(s$timeIn,1,2)) + as.numeric(substr(s$timeIn,4,5))/60
s$y = ifelse(s$nbFish=="school",0.9,1.1)
p3 = ggplot(s, aes(x=mean)) + geom_point(aes(y=y, colour=hour, shape=nbFish), size=4, alpha=0.7) + polar() + scale_y_continuous("",limits=c(0,1.2), breaks=1)
p3


pdf("plots.pdf")
print(list(p1,p2,p3))
dev.off()

#
# 	BlueBidule
#
#		Correct tracks according to the movement of a fixed point in the aquarium and of the north of the compass.
#		Resulting tracks are oriented with respect to cardinal coordinates
#
#	(c) Jean-Olivier Irisson 2005-2007
#	Released under GNU General Public Licence
#	Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# Constant
# FIXME find a way to make px to cm conversion more robust than to use hand made measures - at least make the diameter of the aquarium a preference of the bash program extracted by R
realAquariumDiameter=38.1		# aquarium diameter in cm
library("circular")

# Read data
#-----------------------------------------------------------------------
# Larvae tracks are recorded from ImageJ "Manual tracking"
trackLarva=read.table("track_larva.txt",skip=1,sep="\t")
names(trackLarva)=c("i","trackNb","frameNb","x","y")
trackLarva=trackLarva[,2:5]
# In trackLarva are: trackNb frameNb(=Time) x y
# WARNING: The origin of the position is the upper-left corner

# Reference tracks are recorded from ImageJ "Manual tracking" or "Automatic tracking"
#	automatic tracking: trackNb frameNb(=Time) x y
#	manual tracking: lineNb trackNb frameNb(=Time) x y
trackCompas=read.table("track_compas.txt",skip=1,sep="\t");
if (ncol(trackCompas)>4) {
	trackCompas=trackCompas[,2:5]
}
names(trackCompas)=c("trackNb","frameNb","x","y")

trackFix=read.table("track_fix.txt",skip=1,sep="\t");
if (ncol(trackFix)>4) {
	trackFix=trackFix[,2:5]
}
names(trackFix)=c("trackNb","frameNb","x","y")
# WARNING: The origin of the position is the upper-left corner

# Read calibration data
compas=read.table("coord_compas.txt");
compas=compas[,1:2]
names(compas)=c("centerX","centerY")
aquarium=read.table("coord_aquarium.txt");
names(aquarium)=c("centerX","centerY","perimeter")



# Reformat tracks
#-----------------------------------------------------------------------
# Split larvae tracks
trackLarvaList=split(trackLarva,trackLarva$trackNb)
nbTracks=length(trackLarvaList)

# Put all tracks into a named list
tracks=trackLarvaList
tracks$compas=trackCompas
tracks$fix=trackFix

# Substract the height of the video to y position so that y axis points up
# get height of the video in pixels
# TODO : check for the existence of the command
identifyCommand=system("which identify",intern=T)
# print(identifyCommand)
videoHeight=as.numeric(system(paste(identifyCommand," -format %h stack.tif[0]",sep=""),intern=T))
# print(videoHeight)

# correct
for (l in 1:length(tracks)) {
	tracks[[l]]$y=videoHeight-tracks[[l]]$y
}
# compas and aquarium coordinates have to be treated this way also
compas$centerY=videoHeight-compas$centerY
aquarium$centerY=videoHeight-aquarium$centerY

# Take omited frames into account
show.missing.values <- function(t) 
#
#	Add NAs where there's a skipped frame
#
{
	endFrame = max(t$frameNb)
	frames = 1:endFrame
	# if we don't have all frames, we prepare a new data.frame and put the numbers we have in it
	if (nrow(t) != endFrame) {
		trackNb = t$trackNb[1]
		new = data.frame(trackNb,frames,NA,NA)
		names(new) = names(t)
		new[t$frameNb,]=t
	} else {
		new = t
	}
	return(new)
}
tracks = lapply(tracks,show.missing.values)

# Interpolate missing values in fixed point and compass tracks
fill.missing.values <- function(t) 
#
#	Interpolate NAs in a track using linear interpolation
#
{
	if (any(is.na(t$x))) {
		xInterp = approx(t$frameNb, t$x, t$frameNb)$y
		yInterp = approx(t$frameNb, t$y, t$frameNb)$y
		t$x = xInterp
		t$y = yInterp
	}
	return(t)
}
tracks$compas = fill.missing.values(tracks$compas)
tracks$fix = fill.missing.values(tracks$fix)
# TODO: in the automatic tracking routine, suppress frames when no particle can be observed and leave it to here to do the interpolation. Currently, we do not interpolate, only keep preceeding value
# FIXME: interpolate the compas only after correction by the fixed point track (this will require some clever thinking about the dimensions of both)

# Reduce information to the limiting factor
# larva coordinates without references are useless and references for frame which we have no coordinates for is useless too. therefore we remove useless information
limit = min(sapply(tracks,nrow))
for (l in 1:length(tracks)) {
	tracks[[l]]=tracks[[l]][tracks[[l]]$frameNb<=limit,]
}



# Correct tracks by reference to a fixed point
#----------------------------------------------------------------------- 
# Compute the movement of the fixed point
mvtFixed=as.data.frame(matrix(nrow=limit, ncol=2))
names(mvtFixed)=c("x","y")
# write self explanatory row names
row.names(mvtFixed)=paste(0:(limit-1),"->",1:limit)
# movement at the first time step is zero, it is the reference
mvtFixed[1,]=0
# compute movement
for (i in 1:(limit-1)) {   
	mvtFixed[i+1,] = tracks$fix[i+1,c("x","y")] - tracks$fix[i,c("x","y")] 
}    

# Substract the mouvement of the fixed point to all _other_ tracks    
for (l in 1:length(tracks)) { 	
	if (names(tracks)[l] != "fix") {
		tracks[[l]][,c("x","y")]=tracks[[l]][,c("x","y")]-mvtFixed 	
	} 
} 
# NB: All positions are usually known for the fixed point. Nevertheless, if there are NAs in the track, they are respected here.
# 1/ the movement is NA when one of the positions is NA
# 2/ the positions in other tracks are NA when the movement can't be computed


# Compute larvae tracks in a cardinal reference
#-----------------------------------------------------------------------
# We want to put the North upwards _and_ to correct tracks for rotation during sampling
# To achieve these goals we need to subtract the angle of the compass to the angle of the position of larvae

# Compute the position of the north of the compass in polar coordinates
# NB: angles are trigonometric angles = measured from the horizontal in counter-clockwise direction.
source("lib_circular_stats.R")
compasPol=car2pol(tracks$compas[,c("x","y")],c(compas[1],compas[2]))
compasAngles=compasPol$theta
# in addition, to avoid any mistake we make all angles positive and between [0,2*pi[
compasAngles=(compasAngles+2*pi)%%(2*pi)

# Correct using compas angles
# for all larvae tracks
for (l in 1:nbTracks) {
	# convert track to polar coordinates
	trackPol=car2pol(tracks[[l]][,c("x","y")],c(aquarium$centerX,aquarium$centerY))

	# substract compas angle
	trackPol$thetaCor=trackPol$theta-compasAngles	
	# for un corrected tracks, substract first compas angle in order to be able to compare them with corrected tracks
	trackPol$theta=trackPol$theta-compasAngles[1]
	
	# after this substraction, angles are measured from the horizontal in counter clockwise direction but 0 is in fact the north. we want these angles to behave as regular angles (0 + counter-clockwise) but we want the north to be pointing up so that the trajectories look ok when we switch back to cardinal coordinates. Therefore we need to add pi/2 to these angles
	trackPol$thetaCor = trackPol$thetaCor + pi/2
	trackPol$theta = trackPol$theta + pi/2
	# then we can add them in tracks
	tracks[[l]][,c("x","y")]=pol2car(trackPol[c("theta","rho")])
	tracks[[l]]$bearing=trackPol$theta
	tracks[[l]][,c("xCor","yCor")]=pol2car(trackPol[c("thetaCor","rho")])
	tracks[[l]]$bearingCor=trackPol$thetaCor
	
	# convert x and y positions to human significant measures (mm)
	# conversion factor using the aquarium diameter
	px2cm=realAquariumDiameter/(aquarium$perimeter/pi)
	px2mm=px2cm*10
	tracks[[l]][,c("x","y","xCor","yCor")]=tracks[[l]][,c("x","y","xCor","yCor")]*px2mm
}



# Saving variables for statistical analysis and plotting:
#-----------------------------------------------------------------------
for (l in 1:nbTracks) {
	if (l==1) {
		write.table(tracks[[l]], file="tracks.csv", sep=",", row.names=F)
	} else {
		write.table(tracks[[l]], file="tracks.csv", append=T, sep=",", row.names=F, col.names=F)
	}

}


#
#		BlueBidule
#
#		Library of functions usefull to handle circular data
#			Conversion functions, statistical tests, plots
#
# (c) Jean-Olivier Irisson 2005-2007
# Released under GNU General Public Licence
# Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# Trigonometric functions
#-----------------------------------------------------------------------

car2pol <- function (incar,orig) 
#
# Translates a matrix [x,y] to a matrix [theta,rho] using the provided coordinates of the origin
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

	return(inpol)
}


pol2car <- function (inpol,orig=c(0,0)) 
#
# Translates a matrix [theta,rho] to a matrix [x,y] 
# If coordinates are provided for the origin theay are added to the results
#
{
	# Initiate incar
	incar=inpol
	incar[,]=NA

	# Compute cartesian coordinates
	incar[,1]=inpol[,2]*cos(inpol[,1])
	incar[,2]=inpol[,2]*sin(inpol[,1])	

	# Make the coordinates relative to the origin
	origMat=incar
	origMat[,1]=orig[1]
	origMat[,2]=orig[2]
	incar=incar+origMat
	
	# Change column names
	names(inpol)=c("x","y")	
	
	return(incar)
}


#	Toolbox functions
#-----------------------------------------------------------------------
bootstrap.circ.stats <- function(angles,percentage,n_repet,name){
#
#	Take a sample of a dataset a percentage of the data set
#
#	Aguments:
#	angles: a two collumns matrix of angular data measured in radians first collumn contains rotated data, second contains unrotated data
#   percentage: the percentage of the data to extract
#   n_repet: the number of repetitions of the analysis
#   name: a character string identifying the data
# Result:
#   data: a list of two data frames each containing
#           Name SampleSize MeanAngle CircDisp AngulDev Rbar Pvalue
#         repeated n_repet times
# Details:
#   resamples randomly "percentage" percents of the data and call circ_stats on these resampled sets. It can also check for independence by plotting autocorellograms and mean autocorrelograms
 
  # Prepare storage for the ciruclar stats
  fulldata_rot=data.frame();
  fulldata_norot=data.frame();

  # Prepare storage for the autocorrelation values in a matrix
  #   Each row contains data for a given lag
  #   Each collumn corresponds to a subsampled data set
  nb_obs=length(angles[,1])                                 # Number of observations
  nb_sampled=as.integer(nb_obs*percentage/100);             # Number of sampled elements
  max_lag=60;                                               # Autocorellation max lag
  nb_rows=min(c(nb_sampled,max_lag));                       # Number of rows
  all_acf_rot=matrix(,nb_rows,n_repet);
  all_acf_norot=matrix(,nb_rows,n_repet);
  
  # We repeat the same sequence of operations n_repet times
  for (i in 1:n_repet) {    
    # take a sample of indexes of angles without replacement
    indexes=sample(c(1:nb_obs),nb_sampled,replace=F);
    indexes=sort(indexes)
    # extract data rows from angles
    angles_extr=angles[indexes,];
    # compute autocorrelation
    #dummy=check_indep(angles_extr[,1],paste("resampled positions. repetition",i))
    A_rot=acf(angles_extr[,1],max_lag,plot=F);              # ACF without plot
    all_acf_rot[,i]=A_rot$acf;                              # we store it in the matrix
    A_norot=acf(angles_extr[,2],max_lag,plot=F); 
    all_acf_norot[,i]=A_norot$acf;
    # perform circular statistics on each collumn
    data_rot=circ_stats(angles_extr[,1],paste(name,"_rot",sep=""));
    data_norot=circ_stats(angles_extr[,2],paste(name,"_norot",sep=""));
    # concatenate circular statistics dataframes with previous
    fulldata_rot=rbind(fulldata_rot,data_rot);
    fulldata_norot=rbind(fulldata_norot,data_norot);
  }

  # Compute mean autocorrellation by line
  size=dim(all_acf_rot)[1];
  mean_acf_rot=vector(mode="numeric",size);
  mean_acf_norot=vector(mode="numeric",size);
  for (i in 1:size) {
    mean_acf_rot[i]=mean(all_acf_rot[i,]);
    mean_acf_norot[i]=mean(all_acf_norot[i,]);
  }
  # Plot the mean autocorrelation
  plot(mean_acf_rot,type="h",main=paste("Mean autocorrelogram for resampled",name,"not rotated"),xlab="Lag",ylab="ACF")
  plot(mean_acf_rot,type="h",main=paste("Mean autocorrelogram for resampled",name,"rotated"),xlab="Lag",ylab="ACF")

  # returns a list
  data=list(rot=fulldata_rot,norot=fulldata_norot)
  return(data)
}



# Statistical functions
#-----------------------------------------------------------------------

check.indep <- function(angles,lag=60,name,...)
#
# Computes autocorrelation of the angles series (which gives information on the independance of the data)
#
#	Arguments:
#		angles: a vector of data
#		lag: the maximum lag on which autocorrelation is computed
#		name: a character string used to identify data
#		...: further arguments for acf
#	Result:
#		autocorrelation series as a matrix [1,]
#		plot if plot=FALSE is not specified
#
{
	library("pastecs");

	# Computing autocorellation function
	result=acf(na.exclude(angles),lag.max=lag,main=paste(c("Autocorrelogram for "),name),...);
	# get only the autocorrellation value
	result=t(as.matrix(result$acf))
	
	# Computing a variogram of the data for a maximum lag of 60 frames
	#vario(angles,60);
	#mtext(paste(c("Variogram for "),name));

	return(result)
}


circ.stats <- function(angles,id,trackNb,type,correction)
#
#	Descriptive statistics and test of the directionality of the data
#
#	Aguments:
# 		angles: a vector of class circular
#		id : the VIDEOID of the dataset
#		trackNb: index of the track inside the id
#		type: direction or position
#		correction: wether it is corrected or not (TRUE or FALSE)
#	Result:
#		data: a data frame containing
#			id type correction sampleSize meanAngle circularDispersion angularDeviation rayleighR pValue
#	Details:
# 		The functions computes descriptive statistics about the dataset, such as mean angle, angular dispersion... It also performs Rayleigh's test which calculates the probability of obtaining the observed distribution at random given the number of data.
#
{
	angles=na.exclude(angles)
	sampleSize=length(angles)

	if (sampleSize > 0) {
		library("circular")
		# Rayleigh test
		#-----------------------------------------------------------------
		# rayleigh test
		rayleigh=rayleigh.test(angles)
		# rayleigh statistic = mean resultant length (r) divided by the sample size (N) (close to 1 = non random)
		rayleighR=rayleigh[1]$statistic
		# P value (degree of significance)
		pValue=rayleigh[2]$p.value;

		# Descriptive statistics
		#-----------------------------------------------------------------
		# mean angle
		meanBearing=mean.circular(angles)
		# circular dispersion		[ =(1-r)/N ]
		circularDispersion=var.circular(angles)
		# angular deviation			[ =sqrt(2(1-rayleighR)) ]
		angularDeviation=sqrt(2*(1-rayleighR))
		# TODO check what is the difference between angular deviation and circular dispersion and in what units they are
	} else {
		rayleighR=NA
		pValue=NA
		meanBearing=NA
		circularDispersion=NA
		angularDeviation=NA
	}

	# Summarizing in a data frame
	#--------------------------------------------------------------------	
	data=data.frame(id, trackNb, type, correction, sampleSize, meanBearing, circularDispersion, angularDeviation, rayleighR, pValue)

	return(data)
}



# Plotting functions
#-----------------------------------------------------------------------
plot.aquarium <- function(radius, type)
#
#	Plots a circle of given radius = the aquarium
#
{
	# plot a symbol (circle) of given radius
	symbols(0, 0, radius, inches=F, xlim=c(-radius,radius), ylim=c(-radius,radius) ,xlab="", ylab="", asp=1, xaxt="n", yaxt="n", bty="n")
	
	if (type == "corrected") {
		# write a north arrow
		x=3*radius/4
		# plot a arrow pointing north
		arrows(x,x,x,x+radius/4,length=0.1)
		# Write N at the top of the arrow
		text(x,x+radius/9, labels="N", pos=4)		
	}
}


plot.traject <- function(track, aquariumRadius, main="Trajectory", sub, ...)
#
#	Plots the trajectory as arrows
#		track: a larva track = list with two elements "corrected" and "uncorrected"
#		aquariumRadius: the radius of the aquarium in mm
#		main: main title for the plot
#		sub: 	sub title for the plot (defining which track is plotted)
#		... : additional parameters for arrows
#
{
	for (l in c("corrected","uncorrected")) {
		x=track[[l]]$x
		y=track[[l]]$y
		nbObs=length(x)
		
		# plot the aquarium
		plot.aquarium(aquariumRadius,l)

		# plot the trajectory
		arrows(x[1:(nbObs-1)], y[1:(nbObs-1)], x[2:nbObs], y[2:nbObs], length=0.03, ...)

		# title for the plot
		title(main=main,sub=paste(sub,",",l))		
	}
}

plot.dirs <- function(track, lim, main="Swimming vectors",sub,...)
#
#	Plots the direction vectors as arrows of length proportional to speed
#		track: a larva track = list with two elements "corrected" and "uncorrected"
#		lim: axes limit for the plot (a two element vector)
#		main: main title for the plot
#		sub: 	sub title for the plot (defining which track is plotted)
#		... : additional parameters for arrows
#
{
	library("circular")
	for (l in c("corrected","uncorrected")) {
		angle=as.numeric(conversion.circular(track[[l]]$directionBearing, units="radians", zero=0, rotation="counter"))
		speed=track[[l]]$speed
		nbObs=length(speed)

		# prepare the vectors for 'arrows'
		car=pol2car(cbind(angle,speed))
		car=na.exclude(car)
		x=car[,1]
		y=car[,2]
		orig=x
		orig[]=0

		# plot the swimming vectors
		plot(0, 0, xlim=lim, ylim=lim, asp=1, xlab="", ylab="", main=main,sub=paste(sub,",",l))
		arrows(orig,orig,x,y,length=0.03,...)
	}
}

plot.rose <- function(track, angleType, main="Rose diagram", sub,...)
#
#	Plots a rose diagram
#		track: list with two elements "corrected" and "uncorrected", in each of which there should be a column named "angles"
#		main: main title for the plot
#		sub: 	sub title for the plot (defining which track is plotted)
#		... : additional parameters for rose.diag
#
{
	library("circular")
	for (l in c("corrected","uncorrected")) {
		# extract correct angles, based on angleType argument
		angle = track[[l]]$angles
		
		# convert to geographics template for plotting
		angle = conversion.circular(angle,template="geographics")

		# plot the rose diagram
		rose.diag(angle,...)
		
		# put a title on the plot
		title(main=main,sub=paste(sub,",",l))
	}
}

plot.hist <- function(track, threshold, main="Histogram of swimming speeds", sub, ...) 
#
#	Plots a speed histogram
#		track: a larva track = list with two elements "corrected" and "uncorrected"
#		main: main title for the plot
#		sub: 	sub title for the plot (defining which track is plotted)
#		... : additional parameters for hist
#
{
	for (l in c("corrected","uncorrected")) {
		# plot the speed histogram
		hist(track[[l]]$speed, border=rgb(1,1,1,alpha=0),main=main, sub=paste(sub,",",l), xlab="Swimming speeds (mm/s)",...)
		# draw a dashed vertical line showing which limit speed is taked in consideration in direction stats
		segments(threshold,0,threshold,100,lty=2,lwd=1,col="red")
	}
}





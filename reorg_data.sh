#!/bin/sh
#
#	Reorganise images in the folder hierachy
#
#	Images are stored in a 'DCIM'  directory per day, with a directory structure and names imposed by the camera. Here we extract the images from this complex hierarchy into one sequence of images per day, with names indicating the time the picture was taken.
#
#	(c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#
#------------------------------------------------------------------------------


prefix="../Lizard_Island/data/DISC"

for folder in $(echo ${prefix}/200*); do

	echo "$folder"

	dataSource=${folder}"/DCIM"
	dataDestination=${folder}"/DCIM-all"
	
	# create destination directory if it does not exists
	mkdir -p $dataDestination
	
	# for each picture
	find $dataSource -name "DSC*.JPG" | while read file
	do
		# get date and time of shoot, to the centi-second, using exif tool
		dateTime=$(exiftool -p '${CreateDate}.${SubSecTime}' $file)
		# replace spaces to make it easier to deal with the filename
		newName=$(echo ${dateTime} | tr " " "_" | tr ":" "-")".jpg"
		# echo $(echo $file | awk -F "/" {'print $NF'}) "->" $newName
	
		# create a hard link in the destination directory
		ln $file $dataDestination/$newName
		# when two files have exactly the same time stamp, only, they would end up with the same name but the first one is in fact not overwritten.
	done

done

exit 0

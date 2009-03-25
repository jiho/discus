#!/bin/sh
#
#	Copy images from the folder hierarchy to a large sequence 
#

find . -name "DSC*.JPG" | while read file
do
	# echo $file
	
	folderNumber=$(echo $file | awk -F "NCD" {'print $1'} | awk -F "/" {'print $NF'})
	# echo $folderNumber
	
	fileNumber=$(echo $file | awk -F "_" {'print $NF'})
	# echo $fileNumber
	
	newName=${folderNumber}${fileNumber}
	# echo $newName
	ln $file $newName
done

exit 0

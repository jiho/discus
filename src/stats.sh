#!/bin/bash
#
# BlueBidule
# 
#		Compute statistics and produces plots
#
#
# (c) Jean-Olivier Irisson 2005-2007
# Released under GNU General Public Licence
# Read the file 'src/GNU_GPL.txt' for more information
#
#-----------------------------------------------------------------------

# PREPARATION
#-----------------------------------------------------------------------
# Checking for tracks existence and copy the tracks in the TEMP directory
if [[ -e $DATA/tracks.csv ]]; then
	cp $DATA/tracks.csv $TEMP/
else
	echo -e "\033[1mERROR\033[0m I need tracks. Produce them with \"-tcorrect\" or \"-tcorrect -t\" options"
	exit 1
fi	
cp $DATA/coord_aquarium.txt $TEMP/

# Linking useful statistics functions to TEMP directory
ln -s $RES/lib_circular_stats.R $TEMP/
ln -s $RES/stats.R $TEMP/

# COMPUTE STATISTICS AND PRODUCE PLOTS
#-----------------------------------------------------------------------
echo -e "Computing statistics..."
HERE=`pwd`
cd $TEMP
R CMD BATCH -vanilla stats.R
cd $HERE


# COMMITTING
#-----------------------------------------------------------------------
# Ask the user to commit or not
echo -e "\033[1mCommiting changes\033[0m"; tput sgr0
echo "Do you want to commit changes? (y/n [y]) : "
read -e COMMIT
if [[ "$COMMIT" == "" || "$COMMIT" == "Y" || "$COMMIT" == "y" || "$COMMIT" == "yes" || "$COMMIT" == "Yes" ]]
then		
	# Saving CSV files
	mv -i $TEMP/stats.csv $DATA/$VIDEOID-stats.csv
	mv -i $TEMP/*.pdf $DATA/
	echo "Check $DATA for results"
else
	echo "Ok then cleaning TEMP directory..."
fi
# and we clean temporary directory
rm -f $TEMP/*.csv $TEMP/*.R* $TEMP/*.txt $TEMP/*.pdf $TEMP/.R*



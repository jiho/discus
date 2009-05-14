#!/bin/bash
#
#	Synchronise data between the working drive (DATA) and the storage drive (STORAGE)
#
# (c) Copyright 2009 Jean-Olivier Irisson. GNU General Public License
#------------------------------------------------------------------------------

source src/lib_shell.sh

DATA="../current_data"
STORAGE="/media/data/DISC-Lizard-Nov_Dec_08/DISC/deployments"


# Copy results from data to storage
rsync -avz --exclude='.*' --exclude='*test/'  --exclude='*tmp/' --include='*/' --include='*.csv' --include='*.pdf' --include='*.txt' --exclude='*' $DATA/ $STORAGE

# Synchronize pictures from storage to data
# only those that exist already in the DATA dir
for dir in $(ls -1 $DATA);
do
	echo -e "\n\n$dir"
	rsync -avz --include='*/' --include='*.jpg' --exclude='*' --delete $STORAGE/$dir/ $DATA/$dir
done

exit 0


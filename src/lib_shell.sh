#!/bin/bash
# 
# 	Usefull shell functions
# 
# (c) 2009 Jean-Olivier Irisson <irisson@normalesup.org>. 
# GNU General Public License http://www.gnu.org/copyleft/gpl.html
#
#------------------------------------------------------------

# Quick reference
#   Text attributes
#    0    default
#    1    bold
#    5    blinking
#    7    reverse background and foreground colors
#   Colors    Foreground  Background
#    black    30          40
#    red      31          41
#    green    32          42
#    yellow   33          43
#    blue     34          44
#    magenta  35          45
#    cyan     36          46
#    white    37          47

# echo in bold characters
echoBold () {
	echo -e "\e[1m$1\e[0m"
}

echoB () {
	echoBold "$*"
}

# echo in green
echoRed() {
	echo -e "\e[0;31m$1\e[0m"
}

# echo in green
echoGreen() {
	echo -e "\e[0;32m$1\e[0m"
}

# echo in blue
echoBlue() {
	echo -e "\e[0;34m$1\e[0m"
}

# writes a warning on stantard out
warning() {
	echo -e "\e[0;31m\e[1mWARNING:\e[0m $1\e[0m"
}

error() {
	echo -e "\e[0;31m\e[1mERROR:\e[0m $1\e[0m"
}

#
# Given a range of numbers such as:
#	1,10,1-5,12
# it outputs the list of all numbers, sorted and with duplicates if there are any
#	1 1 2 3 4 5 10 12
#
expand_range() {

	# Change the Internal Field Separator
	IFS=","
	# and that automagically splits the variable in an array using this separator!
	declare -a ids=($1)
	unset IFS	# do not forget to unset it for the rest of the script

	# get the array size
	imax=${#ids[*]}

	# for each element
	for (( i = 0; i < imax; i++ )); do

		# detect whether it contains at least one -
		if [[ $(echo ${ids[$i]} | grep "-") ]]; then
			# if yes then it is a range specificatio and we need to expand it

			# split the string to get the start and the end of the range
			rmin=${ids[$i]%%-*}
			rmax=${ids[$i]##*-}

			# replace the element of the array containing the range specification by the start of the range
			# NB: we do not want the range specification in the final list and that is a way to eliminate it
			ids[$i]=$rmin

			# for the rest of the range, append it to the table, shifting imax accordingly
			for (( j = $((rmin+1)); j <= rmax; j++ )); do
				ids[$imax]=$j
				imax=$((imax+1))
			done
		fi

		# echo the number to stdout in order to sort all numbers
		echo "${ids[$i]}"
	done | sort -n
}

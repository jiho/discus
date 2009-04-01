#!/bin/sh
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
	echo "\e[1m$1\e[0m"
}

echoB () {
	echoBold $1
}

# echo in green
echoRed() {
	echo "\e[0;31m$1\e[0m"
}

# echo in green
echoGreen() {
	echo "\e[0;32m$1\e[0m"
}

# echo in blue
echoBlue() {
	echo "\e[0;34m$1\e[0m"
}

# writes a warning on stantard out
warning() {
	echo "\e[0;31m\e[1mWARNING:\e[0m $1\e[0m"
}

error() {
	echo "\e[0;31m\e[1mERROR:\e[0m $1\e[0m"
}


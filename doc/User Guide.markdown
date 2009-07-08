Title: User Guide
CSS: doc_style.css
Author: Jean-Olivier Irisson

# User documentation for DISCUS

	(c) Copyright 2009 Jean-Olivier Irisson. GNU Free Documentation License

DISCUS stands for DISC User Software, where DISC is Drifting In Situ Chamber. It is a set of scripts used to extract and analyse the data obtained with the DISC. It runs in a terminal, by writing down commands and executing them.

DISCUS runs on Unix-like systems and this guide assumes basic knowledge of such systems including how to use a terminal, basic commands therein, and a package manager. Ubuntu has a nice guide regarding [how to use a Terminal](https://help.ubuntu.com/community/UsingTheTerminal).

All the paths and commands in the following assume you are in the root directory of DISCUS.



## Installation

### Installing dependencies

DISCUS requires the following software to run

* a Unix-like operating system which provides the usual unix tools (awk, sed, rsync, etc.) and a terminal. It has been tested on Linux and Mac OS X.

* the BASH shell environment, which is installed by default on Linux and OS X.

* [ImageJ](http://rsbweb.nih.gov/ij/ "ImageJ"), for most of the image analysis. You need the jar file only. The latest stable version can be downloaded from [http://rsb.info.nih.gov/ij/upgrade/ij.jar](http://rsb.info.nih.gov/ij/upgrade/ij.jar ""); the latest "daily build" is at [http://rsb.info.nih.gov/ij/ij.jar](http://rsb.info.nih.gov/ij/ij.jar ""). Save one of those as `ij.jar` in `src/imagej`.

* a Java Virtual Machine, for ImageJ. DISCUS has been tested with Sun's JVM but the open source one from [OpenJDK](http://openjdk.java.net/ "OpenJDK") should also work. Java is already installed on Mac OS X. Searching for "java" in a package manager on Linux should install the right thing.

* [ExifTool](http://www.sno.phy.queensu.ca/~phil/exiftool/ "ExifTool by Phil Harvey"), a Perl library to access EXIF data in images. Perl itself is already installed on Linux and OS X.

* [R](http://www.r-project.org/ "The R Project for Statistical Computing"), a free software environment for statistical computing and graphics which is used for most of the computation after the image analysis. Features are provided by "packages" and DISCUS requires those two:

	* [ggplot2](http://had.co.nz/ggplot2/ "ggplot. had.co.nz")
	* circular

They should be installed with the commands `install.packages("ggplot2")` and `install.packages("circular")` from within R.

* a PDF reader (evince or xpdf on Linux, Preview on Mac OS X) to preview the plots

* [MPlayer](http://www.mplayerhq.hu/ "Entering MPlayer homepage") when video files are used instead of images

### Checking installation

DISCUS itself is self contained. So once the dependencies are installed it should work. DISCUS will check for the existence of the jar file of ImageJ and the commands in your <a href="http://en.wikipedia.org/wiki/Path_(variable)" title="PATH (variable) - Wikipedia, the free encyclopedia">PATH</a>. Just type

	./bb

in a terminal and if no warnings are issued then you should be all set. Otherwise the error message should be informative enough.




## Data access and storage

### Input files

The data collected with the DISC should be in one "working directory" containing only *numbered* folders, one per deployment, i.e. a folder `work` in your home directory containing folders `1`, `2`, `3` etc. Actions read data from and save their result to files within each deployment directory.

The DISC produces daily recordings of data. They comprise a source of visual information, which can be

* a video recording, on a tape
* a set of pictures in jpeg format, named in sequence according to the settings of the camera. Usually that means split in folders of 1000 images with the a hierarchy such as `DCIM/100ND70S/DSC_0001.JPG`, `DCIM/100ND70S/DSC_0002.JPG`, ... , `DCIM/101ND70S/DSC_0001.JPG`, etc.

and then possibly

* a log of the numerical compass called `compass_log.csv`
* a GPS log in binary format in `gps_log.tsf` and in ASCII format in `gps_log.csv`
* a log of the Starr-Oddi mini-CTD, in binary format in the folder `ctd` and in ASCII format in `ctd_log.dat`

The format of those files should be mostly self explanatory and is detailed in the instructions for each instrument so it is not explained here.

Those daily logs should be split per deployment, in deployments folders. In each folder, DISCUS needs to find at least a source of data (video or pictures) and possibly some compass, GPS, and CTD information. The format of those files is described hereafter. An R script is provided outside of DISCUS to automatically split the daily recordings into deployment folders. Otherwise, pictures/video can be moved manually into the correct folder and logs created by copying and pasting from the complete daily log.

#### Video or pictures

The video file is called `video_hifi.mov` and can be any Quicktime file encoded with a codec readable by MPlayer (that is, almost any file). The H.264 codec has become standard for high quality yet high compression rate video.

The pictures are JPEG files extracted from the video or coming straight of the camera. They are assigned (by the camera or by the video extraction process) [EXIF data](http://en.wikipedia.org/wiki/Exchangeable_image_file_format "Exchangeable image file format - Wikipedia, the free encyclopedia") to store their time stamp. The should be stored in a folder called `pics` and numbered sequentially (`1.jpg`, `2.jpg`,`3.jpg`, etc.) not necessarily starting at 1 (`323.jpg` is a valid first picture, as long as the second is `324.jpg`).

#### Compass

The numerical compass log is a Comma Separated Value file: `compass_log.csv`. The compass can be configured to log many different variables. In our configuration it contains the columns:

* **timestamp** : time in seconds since the compass was plugged in
* **heading** : in degrees
* **pitch** : in degrees
* **roll** : in degrees
* **x/y/zmag** : components of the magnetic field
* **date** : local date and time with the format YYYY-MM-DD HH:MM:SS

The date has to be computed when splitting the daily log into deployment level ones since the compass itself only outputs a timestamp. To do that, the date is recomputed by adding the timstamp (number of seconds since startup) to the start date and time for the day.

#### CTD

The CTD logs data in a CSV file: `ctd_log.csv`, with columns

* **record** : sequential record number
* **date** : local date and time with the format YYYY-MM-DD HH:MM:SS
* **temperature** : in degrees C
* **depth** : in m
* **salinity** : in psu

The original daily CTD logs has the same columns but a different layout and header.

#### GPS

The GPS logs data in a CSV file: `gps_log.csv`, with columns

* **date** : local date and time with the format YYYY-MM-DD HH:MM:SS
* **lat/lon** : in decimal degrees
* **signal** : signal strength

The original daily GPS log has many more columns, most of which are useless here and can be discarded when splitting the data into the deployment level logs.

### Storage

Optionally, the data can be mirrored between this working directory and a storage directory. For example, the storage directory can be on a large, backed-up drive, and contain all deployments while the working directory is on a small, fast drive on which just a few deployments are copied (this is our own setup). The storage directory can also be used as a backup, a source of data for which the analysis is finished and confirmed etc. Its only requirement is to be mounted on the machine and be accessible from the command line. So NFS/Samba/FUSE shares are OK, but must be explicitly mounted somewhere, e.g. in `/media` or `/mnt`.



## Usage


### Invoking DISCUS

DISCUS should be run from its root directory. The user should write `./bb` (which means "execute the file named 'bb' in the current, i.e. '.', directory) and then specify one or several actions, possibly with options, and the deployment(s) to which they should be applied.

The deployments can be specified as single numbers but also ranges and lists (hence the need for deployment folder names to be numeric only). So for example

	./bb foo -joe 4.5 bar 3,5-8,1,32

would apply actions "foo" and "bar" with option "joe" set to 4.5 to deployments 1, 3, 5, 6, 7, 8, and 32.

**Actions** cause DISCUS to do something: output a message, manipulate the data, copy or store data etc. They will be reviewed in sequence in the following sections.

**Options** modify the behaviour of actions for the current call of DISCUS.

**Parameters** set the environment and calibration variables for DISCUS more permanently. When they are modified once, they are kept for all future calls to DISCUS.

Options and parameters can be set in the configuration file (`bb.conf`) or on the command line. Modifying parameters (but not options) on the command line actually stores them in the configuration file for use in later calls, but the file can also be edited directly with a text editor. The options are read in order from the defaults (hard coded into the script), the configuration file (`bb.conf`) and the command line. Meaning that a command-line option will override a configuration file setting for example.

The format of the configuration file is

	option="value"

Lines starting with # are comments. Booleans are written as "TRUE" or "FALSE", in capitals.

For each action that involves modifying data, DISCUS actually works in a temporary directory within the current deployment folder, to avoid mistakes. So, when it has finished, it asks you whether you can to commit this new data from the temporary directory to the deployment folder

	...
	Committing changes
	Do you want to commit changes? (y/n [n]) :

Answering "yes" (or one of y, Y, YES, Yes) confirms the commit but, for each file that already exists in the deployment directory, another confirmation is requested. Answering anything else causes the temporary directory to be removed and its content discarded.


### Getting help

Perhaps the most important action of all: to reach DISCUS' built-in help, you should use the command

	./bb help

or

	./bb h

for short. It outputs something similar to:

![Help Message](images/help_message.png)

When the help action is specified anywhere on the command line, the rest is discarded and only the help message is shown. So

	./bb foo -joe 4.5 help bar 12
	./bb -joe 4.5 foo bar 12 h
	./bb h foo bar 12 -joe 4.5

are equivalent and would only show the help message and not set option "joe", nor execute actions "foo" and "bar".

### Setting up the workspace

The working drive (and possibly the storage drive) need to be defined before starting to use DISCUS on a project

	./bb -work /path/to/working/directory
	./bb -storage /path/to/storage/drive

The paths to the directories need to be absolute. Since `work` and `storage` are parameters, they are stored in the configuration file and only need to be set once. Alternatively, `work` and `storage` can be set directly in the configuration file.

### Getting information about the data

To know what data is available for each deployment, you can use the `status` action

	./bb status

It outputs a listing of the deployments available in the working directory such as

![Status Table](images/status_table.png)

The columns are

* **depl**: deployment number
* **img**: number of images
* **com**: presence of the compass log, can be empty (no compass), `man` (manually tracked compass), or `*` (numerical compass log)
* **gps**: presence of the GPS log, marked by a `*`
* **ctd**: presence of the CTD log, marked by a `*`
* **cal**: calibration step executed, marked by a `*`
* **trk**: status of the larval tracks, can be empty (no tracks), `raw` (tracking step executed by track not yet corrected), or `*` (larvae tracked and tracks corrected)
* **lag**: time difference between two positions on the track, in seconds
* **sta**: statistics computed, marked by a `*`

Alternatively, you can see the status of the deployments in the storage directory by adding the option `-s`

	./bb status -s


### Moving data from/to storage

If you decided to use a storage directory, DISCUS includes two actions to move data back and forth between the working directory and the storage. For example

	./bb get 12

Copies deployment 12 *from* the storage *to* the working directory. When the deployment already exists in the working directory, only the files that are different between storage and working directories are transfered. A list of such files is presented, asking for confirmation before doing the transfer. When some files that are newer in the working directory their equivalent in the storage directory are not considered for transfer to avoid overwriting new result files with old ones.

Conversely

	./bb store 12

copies deployment 12 *from* the working directory *to* the storage. The same behaviour occurs when the deployment already exists in the storage. In addition, it gives a warning when files exists only or are newer in the storage. This is a common scenario if several people share the storage directory and one has analysed and stored deployment 12 before you did.

### Extracting images from a video file

DISCUS works with still images. When the source of data is a video file, it extracts frames from it at a given interval. For example to extract one frame every two seconds from the video of deployment 12

	./bb video -sub 2 12

The `video` action can be abbreviated `v`. The `sub` options sets the subsample rate (1 frame per second by default). The video file has a given number of frames per second and the subsample rate is recomputed to coincide with an integer number of frames. DISCUS informs you of the result which is usually pretty close to what you requested.

### Stabilizing images

In videos in particular, the images can be shaky. The aquarium needs to be at the exact same location on every image for larvae positions to be accurate. The command

	./bb stab 12

opens all the images of deployment 12, computes the movement relative to the first frame and translates all images so that they are aligned with the first frame.

### Getting calibration data

Measuring things on the images gives coordinates in terms of pixels while we are interested in real world positions within the aquarium. So we need to detect the aquarium on the images. The command

	./bb cal 12

opens the first frame of deployment 12 in ImageJ and draws a circle on it.

![Calib Frame Before](images/calib_frame_before.png)

You need to move the anchor points of the circle so that it fits the aquarium. Holding Shift (⇧) forces the modification to respect proportions (i..e the circle stays a circle, not an ellipse). The result should be

![Calib Frame After](images/calib_frame_after.png)

And finally pressing OK on the dialog

![Calib Dialog](images/calib_dialog.png)

causes ImageJ to take some measurements, save them, and close itself.


### Tracking the larva (or the compass) manually

#### Larva

The detection of the larva on each frame is manual. The interface is provided by ImageJ and the command

	./bb larva -sub 10 12

opens a stack (a sequence) of slices (images, frames) for deployment 12, ready for tracking. The option `sub` subsamples one image every 10 seconds instead of opening all of them. Positions at one or two seconds interval are not statistically independent and need to be subsampled at the time of their statistical analysis anyway. So when you are interested in positions only, it makes sense to subsample them directly from here, hence reducing the number of clicks necessary to track the larva. Note that it will prevent the computation of swimming speeds and directions.

You can navigate through the stack using the arrows and the slider at the bottom of the window as well as the keys `<` (previous slice) and `>` (next slice).

![Track Stack](images/track_stack.png)

Basic information is given at the top of the window

![Track Stack Info](images/track_stack_info.png)

The window title contains the name of the stack followed by "(V)" when the stack is "virtual". Virtual stacks open each image from the disk while regular stacks load all images in memory. Therefore, virtual stacks are faster to open but slower to work with. DISCUS decides whether to open a real or virtual stack depending on the number of images to open (i.e. depending on the `sub` option).

The top of the image gives the position in the stack (image 91 on 458 here), the name of the image (375 here), its size (1936x1296) and color model (RGB), and the size of the stack if it was to be saved on the disk.

You start tracking the larva by pressing the "Add track" button on the tracking interface

![Track Interface](images/track_interface.png)

and then clicking the larva on the images. The position of each click is recorded when the mouse button is released and stored in a table

![Track Table](images/track_table.png)

It records:

* **trackNb** : the current track number
* **sliceNb** : the current slice in the stack
* **imgNb** : the name of the associated image
* **x,y** : and the coordinates of the click, in pixels from the bottom left corner of the window.

After each click, the stack moves to the next slice, waiting for another click.

If the click was not exactly where you wanted it, you can delete it with the "Delete last point" button. It removes the data from the table and moves back to the previous slice, ready for a more correct click.

If the whole track is incorrect, you can press the button "End track", select its number in the dropdown menu, and press "Delete track nb". Alternatively "Delete all tracks" deletes everything, bringing you back where you started.

The checkbox "Show path?" causes the trajectory of the larva to be shown as you track it.

Finally, when the final slice is reached, the trajectory is drawn and you can click the OK button in the tracking dialog

![Track Dialog](images/track_dialog.png)

which saves the result table and closes ImageJ.

#### Compass

Tracking the compass for deployment 12, instead of the larva, is just a matter of issuing the command

	./bb compass -sub 15 12

and then clicking the tip of the north needle instead of the larva on each frame. The rest of the tracking is exactly similar. The subsample interval can be different from the one used to track the larva because bearings will be interpolated between the frames anyway. Because of the interpolation and because the instrument usually rotates slowly, large subsample intervals are usually not a problem. When, available, the numerical compass records bearing every 15 seconds, so a 15 seconds interval when using the manual compass instead of the numerical one is customary and make things comparable.

However, we need to know around which point the needle turns to compute bearings. So before opening the stack, the first frame is opened and you must record the position of the center of the compass by clicking on it and then pressing the OK button in the dialog

![Compass Dialog](images/compass_dialog.png)

The tip of the needle at the North and the center of the compass are both small targets and it is necessary to click them very precisely. Indeed the positions will then be converted to angles (headings) and the angular error can be large because the tip of the needle is relatively close to the center of rotation. Therefore, it is a good idea to *zoom in* on the image before clicking the center of the compass or tracking the North. Either use the menu item `Image > Zoom > In`, or the corresponding keyboard shortcut (Ctrl-+ on Linux, ⌘+ on Mac).

### Correcting tracks for rotation

The trajectory of the larva is recorded in the reference of the instrument itself, in pixel coordinates. However we are not interest in whether the larva goes to the left of the right of the image by 20 pixels, but rather whether is goes West or East and at which speed in cm s<sup>-1</sup>.

Because the instrument rotates, we have to correct for the rotation to access the bearings in cardinal reference, with the command

	./bb correct 12

When using the numerical compass, you need to specify the angle between the top of the picture and the direction in which the numerical compass points. To know more about the subject and to know how to compute this angle, please read the "Angles and corrections" document. The angle is then supplied with the parameter `angle`

	./bb -angle 88.3 correct 12

and since it is a parameter, it only has to be specified once unless the camera or the numerical compass are moved relative to each other.

When using a manual compass track, the `angle` parameter is just discarded. Furthermore, without the roll information from the numerical compass, it is impossible to determine whether the camera was above or below the aquarium. Yet, this has consequences in terms of the direction in which the compass appears to be pointing (see the "Angles and corrections" document for details). Therefore, DISCUS asks about that

	Which was the configuration of the instrument:
	1) the camera was ABOVE the arena
	2) the camera was BELOW the arena
	?

and you should type 1 or 2 (anything else causes DISCUS to keep asking).

In addition, DISCUS uses the coordinates of the aquarium recorded in the calibration step to convert pixels to real-world coordinates. So you need to supply the real-world diameter of the aquarium, in cm, with the parameter `diam`

	./bb -diam 40.3 correct 12

This diameter has to match the circle measured in the calibration step. You should usually measure the inner diameter of the aquarium but measuring the outer diameter would be fine as long as you provide the matching number of centimetres here.

### Computing statistics

Finally, once the tracks are recorded and corrected, basic statistics can be computed for each individual larvae, with

	./bb stats 12

As mentioned above, the positions of the larva at 1 or 2 seconds intervals are usually very close to each other. So they are not statistically independent because they cannot be considered like two pieces of information. They are rather the same information, just repeated. Therefore, int he statistical analysis, the positions are subsampled at an interval that makes two successive positions independent from each other. This is done with the options `psub` followed by a number of seconds

	./bb stats -psub 10 12

`psub` equals 5 seconds by default but the value required depends on the swimming speed of larvae in the chamber and on hypotheses about their biology and behaviour.

When the larva is followed on every frame (i.e. when `sub` is not used with the action `larva`), the trajectory, swimming directions, and swimming seeds are computed. Swimming directions can radically change from one second to the next so they are independent and do not require subsampling.

The result of the statistical analysis is a table such as this one

	  trackNb correction   n      mean resample.lag     variance          R
	1       1      FALSE  92        NA           10 1.248551e-03 0.13579271
	2       1       TRUE  92 224.73278           10 5.312841e-05 0.74940596
	3       1      FALSE 356        NA           NA 9.516079e-01 0.04839209
	4       1       TRUE 356 -46.49965           NA 8.524097e-01 0.14759029
	       p.value      kind
	1 1.838480e-01  position
	2 3.993594e-23  position
	3 4.344482e-01 direction
	4 4.287183e-04 direction

It provides descriptive circular statistics for positions and swimming directions and allows to compare uncorrected tracks (in the reference of the instrument) and corrected ones (in cardinal reference). The columns are

* **trackNb**: the number of the track, useful when several individual larvae are tracked
* **correction**: boolean, whether correction for the rotation of the instrument was performed
* **n**: sample size
* **mean**: bearing of the mean vector, in degrees, from the North, clockwise; this is NA for uncorrected track because all points are not in the same cardinal reference so it is meaningless to compute a mean bearing.
* **resample.lag**: for positions, the resampling period as specified by `psub`
* **variance**: angular variance, in radians
* **R**: Rayleigh number; this number characterizes the directionality of the sample: the closed it is to one, the more directional the sample
* **p.value**: *p*-value of the Rayleigh test which compares the observed Rayleigh R to what would be obtained by chance with the same sample size; when the *p*-value is < 0.05, the sample is significantly directional
* **kind**: whether these are position or direction statistics

So the *p*-value gives us the directionality of the sample. But this can still be an artifactual concentration of positions around a particular feature of the aquarium for example. The comparison between corrected and uncorrected statistics can help telling artifacts apart from true orientation. When the positions/directions are more concentrated after the rotation than before, it means that the larva actively corrected against the rotation of the aquarium to stay coser to a given bearing. This is true orientation and is marked by a smaller variance, a larger R, and a smaller p.value after correction.

Finally, DISCUS also produces some graphs to illustrate these results. They are saved in a PDF file and can be displayed after the computation with the options `display` or `d`

	./bb stats -psub 10 -display 12
	./bb stats -psub 10 -d 12

The first one describes the trajectory of the North of the compass throughout the deployment. One point is plotted per position record; the angle is the interpolated bearing of the compass at the time corresponding to the position record; the color is the time elapsed since the start of the data recording, in seconds; the distance from the center increases steadily with time, only to be able to discern episodes when the instrument rotates back and forth.

![Plots Compass](images/plots_compass.png)

This allows to check whether the instrument rotated enough for the comparison between corrected and uncorrected records to be informative.

Then the trajectory of the larva in the aquarium is represented and two panels allow to compare the original trajectory (in the reference of the instrument) and the corrected one (in cardinal reference). Time is represented with the same convention as the preceding plot.

![Plots Traj](images/plots_traj.png)

On this plot, significant directionality is discernible when the trajectory is concentrated within a small region of the aquarium. True orientation manifest itself by a stronger concentration in the corrected trajectory than in the orignal one (as is the case here).

Then follow three different representation of the distribution of positions, which serve a purpose similar to the trajectory plot:

1. dot plot of angles relative to the center of the aquarium, one plot per position recorded
	![Plots Positions](images/plots_positions.png)

2. histogram of angles, which, in circular statistics, is also called a rose diagram
	![Plots Pos Histo](images/plots_pos_histo.png)

3. probability density function of angles, which is basically a continuous version of the histogram
	![Plots Pos Density](images/plots_pos_density.png)

In all of them, the goal is to compare the original to the corrected data, and check in which direction, of any, the corrected data is concentrated. Note that the plots for the orignal data should not have N, E, S, W labels since they are not in a cardinal reference.

Then follows a similar circular histogram (rose diagram) of swimming directions which allows to check for the existence of a preferred swimming bearing or, more often, for bimodal swimming patterns.

![Plots Dir Histo](images/plots_dir_histo.png)

Finally, the frequency distribution of swimming speeds, in cm s<sup>-1</sup>, is represented through a histogram and a probability density function. Swimming speeds are only computed for the original track since we are now interested in the actual swimming speeds in the aquarium. The correction by the rotation introduces artificial movement which is unwanted here.

![Plots Speed Histo](images/plots_speed_histo.png)
![Plots Speed Dens](images/plots_speed_dens.png)

**NOTA BENE** When positions are subsampled, the trajectory, swimming directions, and speeds cannot be computed and the associated graphs are not produced.


### Output files

#### Aquarium coordinates

The `cal` action produces the file `coord_aquarium.txt` which contains the coordinates of the centroid (X, Y) and the perimeter (Perim) of the circle that is fitted to the aquarium.

#### Manual compass track and coordinates

The `compass` action produces:

* `coord_compass.txt` which contains the mean value (Mean) and coordinates (X,Y) of the pixel that is clicked on the image as well as the slice number (Slice, =1). Mean and Slice are discarded.

* `compass_track.txt` which contains the result table of the tracking routine, already described above (trackNb, sliceNb, imgNb, x, and y)

#### Larva track (raw and corrected)

The raw larva track in `larvae_track.txt` produced by the action `larva` is exactly identical to the compass track described above.

After correction by `correct`, the corrected track is saved in `tracks.csv`. It contains

* **trackNb/sliceNb/imgNb** : same as before
* **exactDate** : local date and time with fractional second in the format YYYY-MM-DD HH:MM:SS.S
* **date** : local date and time in the format YYYY-MM-DD HH:MM:SS
* **x,y** : cartesian position, in cm from the center of the aquarium
* **theta,rho** : polar position, in degrees (from the north and clockwise) and cm from the center of the aquarium
* **compass** : interpolated compass reading in degrees (from the north and clockwise)
* **correction** : boolean specifying whether this is the original track (correction = FALSE) or corrected (correction = TRUE)
* **heading** : swimming direction in degrees (from the north and clockwise)
* **speed** : swimming speed in cm s<sup>-1</sup>

Unavailable values are marked as NA.

#### Statistics and plots

The action `stats` stores the statistic table in `stats.csv` and the plots in `plots.pdf`. The content and purpose of both were already described above.



## Trouble shooting

### Memory issues

ImageJ, the software that is used for more of the image analysis and data acquisition, has a fixed amount of memory dedicated to it. By default 1000 MB here (almost 1 GB). Depending on the size of your images and the subsample intervals, some image stacks (used in the tracking phase) may be bigger than that. If ImageJ reports an out of memory issue, you can increase it with

	./bb -mem 2000
	./bb -m 2000

which will dedicate 2000 MB of memory to ImageJ for this run and the following ones (`mem` is a parameter). ImageJ developers advise to dedicate at most 2/3 of the physical memory of your machine to ImageJ. Dedicating more might result in degraded performance.

### Ultra-simple debugging

Despite our efforts, there are probably still bugs lingering around in the code, waiting to be discovered. If you encounter a weird behaviour, you can add some debugging information in the code quite easily to pinpoint the culprit.

The file `bb` is just a text file and can be opened, modified, and saved in a text editor (Gedit, Text Edit etc.). The modified version is then immediately able to run. You can have `bb` display messages at various point in the code by inserting a new line containing the `echo` command

	echo "This is a debugging message"

This prints "This is a debugging message" (without the quotes) in the terminal when the line is reached. This way you can see how far `bb` goes before running into your issue. The beginning of the file is mostly configuration and the actions start to run after line 350.

In addition, when bb calls other programs (ImageJ, R, etc.), most of their output is masked for cleanness. You can modify the code to show it:

* For ImageJ, search for constructs such as

		> /dev/null 2>&1

	and suppress them.

* For R, search for `-slave` and replace it by `-vanilla`

Hopefully, having to do that should not happen very often.

//
//  Run Image stabilization
//
//  This is done in a macro to be able to call it as a batch job
//
//  (c) Copyright 2005-2011 J-O Irisson, C Paris
//  GNU General Public License
//  Read the file 'src/GNU_GPL.txt' for more information
//
//------------------------------------------------------------

// Get deployment directory as argument
deployDir = getArgument;

// Open images as a virtual stack
run("Image Sequence...", "open="+deployDir+"/pics/*.jpg number=0 starting=1 increment=1 scale=100 file=[] or=[] sort use");

// Run the Image Stabilizer plugin
// it translates avery image so that it is inline with the first one
// and outputs the corrected images in the directory given as argument here
run("Image Stabilizer", deployDir+"/tmp/pics");

// Quit imageJ
run("Quit");

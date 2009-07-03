//
//  Run Image stabilization
//
//  This is done in a macro to be able to call it as a batch job
//
//  (c) Copyright 2009 Jean-Olivier Irisson.
//  GNU General Public License
//  Read the file 'src/GNU_GPL.txt' for more information
//
//------------------------------------------------------------

// Get deployment directory as argument
deployDir = getArgument;

// Open images as a virtual stack
run("Image Sequence...", "open="+deployDir+"/pics/*.jpg number=0 starting=1 increment=1 scale=100 file=[] or=[] sort use");

// Run the stabilizer plugin
run("Image Stabilizer", deployDir+"/tmp/pics");

// Quit imageJ
run("Quit");

import java.awt.*;
import java.awt.event.*;
import java.util.*;
import ij.*;
import ij.gui.*;
import ij.process.*;
import ij.measure.*;
import ij.plugin.filter.PlugInFilter;
import ij.plugin.filter.ParticleAnalyzer;
import ij.plugin.filter.Analyzer;
//import java.awt.Color;


public class Auto_Tracking implements PlugInFilter, Measurements {

/*-----------------------------------------------------------------------
 This plugin tracks one particle through a stack using distance criteria to distinguish between particles. It outputs coordinates of the centroid of the particle on each frame.
  It has to start with a frame with only ONE particle: the one which has to be followed.

	(c) Jean-Olivier Irisson 2005-2007
	Released under GNU General Public Licence
	Read the file 'src/GNU_GPL.txt' for more information
   Modification of the Object Tracker plugin by Wayne Rasband
     http://rsb.info.nih.gov/ij/plugins/tracker.html
   and MultiTracker plugin by Jeffrey Kuhn
     http://rsb.info.nih.gov/ij/plugins/multitracker.html
-----------------------------------------------------------------------*/

	ImagePlus	img;      // the image in ImageJ
	static int minSize, maxSize;

	/* This method sets up the plugin filter to use 
		 (= the type of image that can be processed) */
  public int setup(String arg, ImagePlus img) {
		this.img = img;
		if (IJ.versionLessThan("1.17y"))
			return DONE;
		else
			return DOES_8G+NO_CHANGES;	// 8 bit gray scale image
	}


	public void run(ImageProcessor ip) {
		/* Check if we have a stack */
		int nFrames = img.getStackSize();	// number of frames
		if (nFrames<2) { // if number of frames <= 1 we don't have a stack
			IJ.showMessage("Auto Tracking", "Stack required");
			return;
		}
		
		/* Measure the area of the particle on the first frame 
		   and set the range in area to consider in the following */
		ImageStack stack = img.getStack();
		ResultsTable rt = new ResultsTable();
		rt.reset();
		// We define our particle analyzer with all options false (0), measures: AREA
		// results output in rt, min and max size of particles: 1, 99999)
		ParticleAnalyzer pa = new ParticleAnalyzer(0, AREA, rt, 1, 99999);
			// We analyse the first frame
		pa.analyze(img, stack.getProcessor(1));
			// And extract the area
		float area = rt.getValue(ResultsTable.AREA,0);
		rt.reset();
			// The tolerance in particle size in provided by the user through a dialog
		int tolerance=70;
		GenericDialog gd = new GenericDialog("Auto Tracking");
		gd.addNumericField("Tolerance in object size (pixels): ", tolerance, 0);
		gd.showDialog();
		if (gd.wasCanceled())
			return;
		tolerance = (int)gd.getNextNumber();
			// The size range is computed
		minSize = (int)area - tolerance;
		maxSize = (int)area + tolerance;
		
		/* Prepare Tracking */
		// Get the maximum and minimum numbers of particles in all the frames
		rt.reset();
		int nParticlesMax = 1, nParticlesMin = 1, nParticlesTemp;
		for (int iFrame=1; iFrame<=nFrames; iFrame++) {
			rt.reset();
			pa = new ParticleAnalyzer(0, CENTROID, rt, minSize, maxSize);
			pa.analyze(img, stack.getProcessor(iFrame));
			nParticlesTemp = rt.getCounter();
			if ( nParticlesTemp > nParticlesMax ) {
				nParticlesMax = nParticlesTemp;
				//IJ.showMessage("Auto Tracking", "There are "+nParticlesTemp+" particles on frame "+iFrame);
			}
			if ( nParticlesTemp < nParticlesMin ) {
				nParticlesMin = nParticlesTemp;
				//IJ.showMessage("Auto Tracking", "There is less than one particle on frame "+iFrame);
			}
		}
		// Issue Warnings when needed
  	if (nParticlesMax > 1) {
      GenericDialog gderr1 = new GenericDialog("Auto Tracking");  
      gderr1.addMessage("You have more than one particle on at least one slide.\n The tracking algorithm can try to follow the fixed point.\n Do you want to continue tracking anyway ?");
		  gderr1.showDialog();
		  if (gderr1.wasCanceled())
		  	return;
			//IJ.showMessage("Auto Tracking", "You have more than one particle on at least one slide");
		}
		if (nParticlesMin < 1) {
      GenericDialog gderr2 = new GenericDialog("Auto Tracking");  
			gderr2.addMessage("You have no particle on at least one slide.\n The tracking algorithm will consider that the point did not move.\n Do you want to continue tracking anyway ?");
		  gderr2.showDialog();
		  if (gderr2.wasCanceled())
		  	return;
		}
		// Prepare storage
		float[] xOld = new float [nParticlesMax];
		float[] yOld = new float [nParticlesMax];
		float[] xSrc = new float [nParticlesMax];
		float[] ySrc = new float [nParticlesMax];
		float[] xDest = new float [nParticlesMax];
		float[] yDest = new float [nParticlesMax];
		// Prepare Results Table
		ResultsTable rslt = new ResultsTable();
		rslt.reset();
			// create the column headings based on the number of particles
		String strHeadings = "Track Nb\tSlice Nb";
		//for (int i=1; i<=nParticlesMax; i++) {
		for (int i=1; i<=1; i++) {
			strHeadings += "\tX" + i + "\tY" + i;
		}
		IJ.setColumnHeadings(strHeadings);
		
		
		/* Now go through each frame, find and reorder the particle positions */
		for (int iFrame=1; iFrame<=nFrames; iFrame++) {
			// Run the particle analyser
			rt.reset();
			pa = new ParticleAnalyzer(0, CENTROID, rt, minSize, maxSize);
			pa.analyze(img, stack.getProcessor(iFrame));
				// Extract the coordinates of the centroids of all the particles
			float[] xExtract = rt.getColumn(ResultsTable.X_CENTROID);				
			float[] yExtract = rt.getColumn(ResultsTable.Y_CENTROID);
				// If there are no particles on one slide we consider that the point didn't move since last time step 
			if (xExtract==null){
        xExtract = new float [nParticlesMax];
        yExtract = new float [nParticlesMax];        
				for (int i=0; i<nParticlesMax; i++) {
        	xExtract[i] = xDest[i];
          yExtract[i] = yDest[i];
        }
      }
			// Put the positions in source array (0 where there is no data)
			int nParticlesCurrent = xExtract.length;
			for (int i=0; i<nParticlesMax; i++) {
				if (i < nParticlesCurrent) {
					xSrc[i]=xExtract[i];
					ySrc[i]=yExtract[i];
				} else {
					xSrc[i]=0;
					ySrc[i]=0;
				} 
			}
			// Sort the tracks using distance criterium
			if ( iFrame == 1 ) { 
				// we have nothing to sort for the first frame we just copy
				for (int i=0; i<nParticlesMax; i++) {
					xDest[i]=xSrc[i];
					yDest[i]=ySrc[i];
				}
			} else {
				// Copy the coordinates of previous time step and reinitialize destination table 
				for (int i=0; i<nParticlesMax; i++) {
					xOld[i]=xDest[i];
					yOld[i]=yDest[i];
					xDest[i]=0; yDest[i]=0;
				}
				// For each particle of previous time step find the closest particle in current time step
				double Dist, minDist;
				int indexMinDist;
				//for (int i=0; i<nParticlesMax; i++) {
				// We are just interested in following the first particle
				for (int i=0; i<1; i++) {
					//if (xSrc[i] !=0 && ySrc[i] != 0) {
					// initialization of the distance calculation
					minDist = Math.sqrt(sqr(xSrc[0] - xOld[i]) + sqr(ySrc[0] - yOld[i]));
					indexMinDist = 0;
					for (int j=1; j<nParticlesMax; j++) {
						// calculate the distance from the j'th new point to the i'th old point
						Dist = Math.sqrt(sqr(xSrc[j] - xOld[i]) + sqr(ySrc[j] - yOld[i]));
						if ( Dist < minDist ) {
							minDist = Dist;
							indexMinDist = j;
						}
					}
					// Copy particles positions in correct order from source array
					xDest[i]=xSrc[indexMinDist];
					yDest[i]=ySrc[indexMinDist];
					//}
					/* NB: with this method we actually cannot follow many particles at once. To do that we need absolute minimization and a smarter choice for reordering the particles */
				}
			}
		
		// Write the results to the results table
		String strLine = "1\t" + iFrame;
		//for (int i=0; i<nParticlesMax; i++) {
		for (int i=0; i<1; i++) {
			strLine += "\t" + xDest[i] + "\t" + yDest[i];
		}
		IJ.write(strLine);
		IJ.showProgress((double)iFrame/nFrames);
		}

	}

double sqr(double n) {return n*n;}

}



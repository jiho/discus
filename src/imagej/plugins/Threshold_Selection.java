import ij.*;
import ij.process.*;
import ij.gui.*;
import java.awt.*;
import ij.plugin.*;


public class Threshold_Selection implements PlugIn {
/*-----------------------------------------------------------------------
	This plugins runs on an image of a stack containing a selection (ROI)
	It covers the remaining of the images of the stack with foreground color (black) and thresholds what is in the ROI. Then it applies watershed to separate overlapping elements

	(c) Jean-Olivier Irisson 2005-2007
	Released under GNU General Public Licence
	Read the file 'src/GNU_GPL.txt' for more information

-----------------------------------------------------------------------*/
	
	public void run(String arg) {
		// Filling outside with black
		IJ.run("Make Inverse");
		IJ.run("Fill", "stack");
		IJ.run("Select None");
		// Threshold
      // A dialog allows to choose to which type of object the threshold is applied
    String[] choices = new String [2];
    choices[0] = "fixed point";
    choices[1] = "compass";
    GenericDialog gd = new GenericDialog("Threshold_Selection");
    gd.addChoice("Which element are you thresholding?",choices,"fixed point");
		gd.showDialog();
		if (gd.wasCanceled())
			return;
    String type = gd.getNextChoice();
      // The parameters of the Threshold depend on the object thresholded
    IJ.run("Threshold...");
    if (type=="fixed point")
      IJ.setThreshold(150, 255);
    else 
      IJ.setThreshold(70, 255);
		IJ.run("Threshold", "thresholded remaining black stack");
    // Watershed
    IJ.run("Watershed", "stack");
	}
	
}

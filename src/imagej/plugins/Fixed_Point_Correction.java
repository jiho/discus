import ij.plugin.filter.PlugInFilter;//import java.awt.Color;import ij.*;import ij.gui.*;//import ij.process.*;//import ij.plugin.filter.ParticleAnalyzer;//import ij.measure.*;
import java.util.*
import java.io.*

public class Fixed_Point_Correction implements PlugInFilter  {
/**
 *
 *		Reads the movement of the fixed point and moves the slices of a
 *		stack in order to correct for this movement
 *
 */

	String resultsFile="track_fix.txt"
	
	// Open the file
	FileInputStream fis =  new FileInputStream(resultsFile)
	InputStreamReader isr = new InputStreamReader(fis)
		LineNumberReader lnr = new LineNumberReader(isr);
	
while(true){	    line = lnr.readLine();	    // detection of EOF	    if (line == null) break;	    if ((nLine > row-1) & (nLine < row+n)){		fields = line.split("\\s+");		vector.addElement(fields[col]);	    }	    nLine++;	}	return vector;
	
	
	//cf.	 http://www.neurotraces.com/edf/CreatingEDF/node5.html
	
	
//	ImagePlus imp;
	
	// Verify stack size
	int nFrames = imp.getStackSize();
	if (nFrames<2) {		IJ.showMessage("Fixed Point Correction", "Stack required");		return;	}
		ImageStack stack = imp.getStack();
	

}
import ij.*;
import ij.process.*;
import ij.gui.*;
import java.awt.*;
import ij.plugin.*;
import ij.plugin.filter.PlugInFilter;
import ij.plugin.filter.Duplicater;
import ij.plugin.filter.RGBStackSplitter;
import ij.measure.*;


public class Threshold_Stack implements PlugInFilter {

    ImagePlus im1;
    ImagePlus im2;
    ImageStack stack1;
    ImageStack stack2;

    public int setup(String arg, ImagePlus im1) {
        this.im1 = im1;
        return DOES_ALL+STACK_REQUIRED;
    }

    public void run(ImageProcessor ip) {

        // Duplicate stack
        Duplicater du = new Duplicater();
        im2 = du.duplicateStack(im1, "duplicate.tif");
        
        im2.show();

        // Delete last slice of the original slice
        stack1 = im1.getStack();
        stack1.deleteLastSlice();

        // Delete first slice of the new stack
        stack2 = im2.getStack();
        stack2.deleteSlice(1);

        // Put these modified stacks back in the images
        im1.setStack(null, stack1);
        im2.setStack(null, stack2);
        
        im1.show();
        im2.show();

        // Subtraction operation
        ImageCalculator calc = new ImageCalculator();
        calc.calculate("Subtract stack", im1, im2);
        // the subtraction stores the result in im1

        // Split the color channels
        RGBStackSplitter split = new RGBStackSplitter();
        split.split(stack1, false);
        // Construct a new image with the blue channel only
        ImagePlus imB = new ImagePlus("blue.tif", split.blue);
        
        imB.show();
        
        // Isolate the aquarium
        IJ.setTool(1);
        IJ.makeOval(410, 62, 1114, 1114);
        IJ.run("Clear Outside", "stack");
        
        // Threshold the image to black and white
        // IJ.run("Threshold", "thresholded remaining stack");
        IJ.setThreshold(29, 255);
        IJ.run("Convert to Mask", " ");
        
        imB.updateAndDraw();
    }
    
}

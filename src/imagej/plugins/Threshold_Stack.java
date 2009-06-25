import ij.*;
import ij.process.*;
import ij.gui.*;
import java.awt.*;
import java.awt.event.*;
import ij.plugin.*;
import ij.plugin.filter.PlugInFilter;
import ij.plugin.filter.Duplicater;
import ij.plugin.filter.RGBStackSplitter;
import ij.plugin.filter.ParticleAnalyzer;
import ij.plugin.filter.Analyzer;
import ij.measure.*;


public class Threshold_Stack implements PlugInFilter, Measurements {

    ImagePlus im1;
    ImagePlus im2;
    ImageStack stack1;
    ImageStack stack2;
    ImageWindow win;
    ImageCanvas canvas;
    WaitForUserDialog wd;
    GenericDialog gd;
    ResultsTable rt;
    ResultsTable rp;


    public int setup(String arg, ImagePlus im1) {
        this.im1 = im1;
        return DOES_ALL+STACK_REQUIRED;
    }

    public void run(ImageProcessor ip) {

        // Compute the image per image difference of the stack
        //------------------------------------------------------------
        // The goal is to suppress as much of the background as possible and images that are next to each other in a sequence are those that have the most similar backgrounds.

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


        // Extract the particles present on the blue component
        //------------------------------------------------------------
        // After the difference, the larva is mostly blue so we isolate that and threshold the image to transform the blue items on a black background into black particles on a white background

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


        // Gather characteristics of the larva
        //------------------------------------------------------------
        // To track the larva on successive images, we will compute several of its geometrical moments: area, major and minor axes of the best fit ellipse etc. This will vary from frame to frame so we need to have a reference and an idea of how much those moments vary around that reference. To do that, we ask the user to click the larva on several images and extract the moments of the corresponding particles

        // // Select the larva on the first frame
        // IJ.setTool("point");
        // // TODO: use a non modal simple, raw Java dialog
        // wd = new WaitForUserDialog("Track Larva", "Please click on the larva\nand close this window");
        // wd.show();

        // // Use direct measurements
        // ResultsTable rt = new ResultsTable();
        // Analyzer ana = new Analyzer(imB, CENTROID, rt);
        // ana.setMeasurement(CENTROID, true);
        // ana.setMeasurement(AREA, true);
        // ana.setMeasurement(ELLIPSE, true);
        // ana.measure();
        // rt = ana.getResultsTable();
        // rt.show("Results");

        // // Click on several frames and detect the larva
        // win = im1.getWindow();
        // canvas = win.getCanvas();
        // canvas.addMouseListener(this);


        // Track the larva through the stack
        //------------------------------------------------------------
        // Use the particle analyser to follow the larva. We start by detecting all particles on each slice and then filter out those that do not match the characteristics of the larva

        ImageStack stackB = imB.getStack();
        // stack size
        int n = imB.getImageStackSize();

        // Set the geometric moments that are measured
        Analyzer a = new Analyzer(imB);
        a.setMeasurement(CENTROID, true);
        a.setMeasurement(ELLIPSE, true);
        a.setMeasurement(AREA, true);
        int measurements = a.getMeasurements();

        // Set tolerances manually for now
        float meanMajor = 27;
        float tolMajor = (float) 0.2 * meanMajor;   // 20% tolerance
        float minMajor = meanMajor - tolMajor;
        float maxMajor = meanMajor + tolMajor;

        float meanMinor = 8;
        float tolMinor = (float) 0.3 * meanMinor;   // 20% tolerance
        float minMinor = meanMinor - tolMinor;
        float maxMinor = meanMinor + tolMinor;

        float meanArea = 175;
        double tolArea = (double) 0.6 * meanArea;   // 50% tolerance
        double minArea = meanArea - tolArea;
        double maxArea = meanArea + tolArea;

        // Prepare per slice and total result tables
        ResultsTable r = new ResultsTable();
        ResultsTable rtmp = new ResultsTable();

        for (int i=1; i<=n; i++) {
            System.out.println("Slice "+i);

            // Clear per-slice table
            rtmp.reset();

            // Create particle analyzer with no options and a size filter
            ParticleAnalyzer pa = new ParticleAnalyzer(0, measurements, rtmp, minArea, maxArea);
            // Analyse particles
            pa.analyze(imB, stackB.getProcessor(i));

            rtmp.show("Particles");

            // Nb of particles
            int nP = rtmp.getCounter();
            System.out.println("  nb of particles "+nP);

            // Filter particles
            // whether particles match the characteristics of the larva or not
            boolean[] match = new boolean[nP];
            // initially all matching
            for (int m=0; m<=nP-1; m++) {
                match[m] = true;
            }
            // nb of matching particles
            int nPgood = nP;

            // Filter based on parameters of the gest fit ellipse
            float[] ellipsMajor = rtmp.getColumn(rtmp.getColumnIndex("Major"));
            float[] ellipsMinor = rtmp.getColumn(rtmp.getColumnIndex("Minor"));
            for (int m=0; m<=nP-1; m++) {
                if (ellipsMajor[m] < minMajor || ellipsMajor[m] > maxMajor || ellipsMinor[m] < minMinor || ellipsMinor[m] > maxMinor) {
                    match[m] = false;
                    nPgood--;
                }
            }

            System.out.print("  "+nPgood);

            switch (nPgood) {
                case 0: System.out.println(" => No good particle");
                break;
                case 1: System.out.println(" => One good particle");
                break;
                default: System.out.println(" => Several good particles");
            }
        }
    }

    // public void mouseReleased(MouseEvent m) {
    //     // Get clicked coordinates
    //     int x = m.getX();
    //     int y = m.getY();
    //     int ox = canvas.offScreenX(x);
    //     int oy = canvas.offScreenY(y);
    //
    //     System.out.println(x+","+y);
    //     System.out.println(ox+","+oy);
    //
    //     // Add the data to the result table
    //     rt.incrementCounter();
    //     rt.addValue(0,im1.getCurrentSlice());
    //     rt.addValue(1,ox);
    //     rt.addValue(2,oy);
    //
    //     rt.show("Coords");
    //
    //     // Stop tracking
    //     canvas.removeMouseListener(this);
    // }
    // public void mousePressed(MouseEvent m) {}
    // public void mouseExited(MouseEvent m) {}
    // public void mouseClicked(MouseEvent m) {}
    // public void mouseEntered(MouseEvent m) {}

}

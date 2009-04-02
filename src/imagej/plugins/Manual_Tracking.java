/*-----------------------------------------------------------------------

	Manual tracking v2.0, 15/06/05

	Simplification of the plugin by Fabrice P Cordelières, fabrice.cordelieres at curie.u-psud.fr
-----------------------------------------------------------------------*/

import java.awt.*;
import java.awt.event.*;
import java.awt.SystemColor;
import java.io.*;
import java.lang.*;
import java.util.StringTokenizer;
import ij.*;
import ij.gui.*;
import ij.io.*;
import ij.measure.*;
import ij.plugin.Converter;
import ij.plugin.frame.*;
import ij.plugin.filter.*;
import ij.plugin.filter.Duplicater;
import ij.process.*;
import ij.process.StackConverter;
import ij.util.*;
import ij.util.Tools.*;

public class Manual_Tracking extends PlugInFrame implements ActionListener, ItemListener, MouseListener {


    //Calibration related variables---------------------------------------------
    double calxy=1; //This value may be changed to meet your camera caracteristics
    double calz=0; //This value may be changed to meet your piezo/Z-stepper caracteristics
    double calt=1; //This value may be changed to meet your timelapse settings
    int cent=5; //Default side size for the square where the center is searched
    int dotsize=5; // Drawing parameter: default dot size
    double linewidth=1; // Drawing parameter: default line width
    int fontsize=12; // Drawing parameter: default font size
    Color[] col={Color.blue,Color.green,Color.red,Color.cyan,Color.magenta,Color.yellow,Color.white}; //Values for color in the drawing options


    //Universal variables-------------------------------------------------------
    int i;
    int j;
    int k;
    int l;
    int m;
    int n;
    String txt;


    //Interface related variables-----------------------------------------------
    static Frame instance;
    Font bold = new Font("",3,12);
    Panel panel;
    //Tracking
    Button butAdd;
    Button butDlp;
    Button butEnd;
    Button butDel;
    Choice trackdel;
    Button butDelAll;
    Checkbox checkPath;
    //Centring
    Choice choicecent;
    Checkbox checkCent;
    Label labelCorr;
    //Directionality
    Button butAddRef;
    Button butDelRef;
    Label titleRef;
    Checkbox checkShowRef;
    Checkbox checkRef;
    //Drawing
    Button butOvd;
    Button butOvl;
    Button butOvdl;
    Button butOverdots;
    Button butOverlines;
    Button butOverboth;
    Checkbox checkText;
    //Load/Param/Retrieve
    Button butLoad;
    Checkbox checkParam;
    Button butRetrieveZ;
    //Parameters
    Label labelEmpty1;
    Label labelEmpty2;
    Label labelEmpty3;
    Label labelEmpty4;
    Label labelParam;
    Label labelEmpty5;
    Label labelTime;
    TextField caltfield;
    Choice choicecalt;
    Label labelxy;
    TextField calxyfield;
    Choice choicecalxy;
    Label labelz;
    TextField calzfield;
    Label labelEmpty6;
    Label labelCent;
    Label labelPix;
    TextField centsize;
    Label labelDot;
    TextField dotsizefield;
    Label labelEmpty7;
    Label labelLine;
    TextField linewidthfield;
    Label labelEmpty8;
    Label labelFont;
    TextField fontsizefield;
    Label labelEmpty9;


    //Image related variables---------------------------------------------------
    ImagePlus img;
    String imgtitle;
    int Width;
    int Height;
    int Depth;
    int Slice;
    String SliceTitle;
    ImageCanvas canvas;
    ImagePlus ip;
    ImageStack stack;
    ImageWindow win;
    StackConverter sc;
    Duplicater dp;


    //Tracking related variables------------------------------------------------
    boolean islistening=false; //True as long as the user is tracking

    int[] xRoi; //Defines the ROI to be shown using the 'Show path' option - x coordinates
    int[] yRoi; //Defines the ROI to be shown using the 'Show path' option - y coordinates
    Roi roi; //ROI
    int Nbtrack=1; // Number of tracks
    int NbPoint=1; // Number of tracked points in the current track
    int ox; //x coordinate of the current tracked point
    int oy; //y coordinate of the current tracked point
    int PixVal; //intensity of the current tracked point
    int prevx; //x coordinate of the previous tracked point
    int prevy; //y coordinate of the previous tracked point
    double Distance; //Distance between (ox,oy) and (prevx, prevy)
    double Velocity; //Distance/calt
    int pprevx; //x coordinate of the antepenultimate tracked point
    int pprevy; //y coordinate of the antepenultimate tracked point


    //Centring correction related variables--------------------------------------
    String commentCorr; //Stores the tracked point coordinates and the corrected point coordinates


    //Reference related variables-----------------------------------------------
    boolean islisteningRef=false; // True when the add reference button has been clicked.
    boolean RefSet=false; // True if a reference has already been set
    int DirIndex=1; //1 for anterograde movement, -1 for retrograde movement
    int refx=0; // x coordinate of the reference pixel
    int refy=0; // y coordinate of the reference pixel
    Roi roiRef; // Circular region drawn around the reference


    //Dialog boxes--------------------------------------------------------------
    GenericDialog gd;
    GenericDialog gd1;
    GenericDialog gd2;
    GenericDialog VRMLgd;
    OpenDialog od;
    SaveDialog sd;
    String FileName; // Filename with extension
    String File; // Filename without extension
    String dir; // Directory


    //Results tables------------------------------------------------------------
    ResultsTable rt; //2D results table
    ResultsTable rtmp; // Temporary results table
    String[] head={"trackNb","sliceNb","x","y"}; //2D results table's headings
    ResultsTable rt3D; //3D results table

    //Load Previous Track File related variables--------------------------------
    BufferedReader in; //Input file
    String line; //Input line from the input file
    StringTokenizer Token; //used to separate tab delimited values in the imported file


    //Retrieve z coordinates dialog box & variables-----------------------------
    String[] CentringArray={"No centring correction", "Barycentre in signal box", "Max intensity in signal box"}; //List of options in the centring correction choicelist
    int Centring; //3D centring option nº
    int sglBoxx; //Width of the signal box
    int sglBoxy; //Height of the signal box
    int sglBoxz; //Depth of the signal box
    int bkgdBoxx; //Width of the background box
    int bkgdBoxy; //Height of the background box
    int bkgdBoxz; //Depth of the background box
    String[] QuantificationArray={"No background correction", "Bkgd box centred on sgl box", "Bkgd box on top left" , "Bkgd box on top right" , "Bkgd box on bottom left", "Bkgd box on bottom right"}; //List of options in the quantification settings choicelist
    int Quantification; //3D quantification option nº
    boolean DoQuantification; //True if the Do quantification checkbox is checked
    boolean DoBleachCorr; //True if the Do bleaching correction checkbox is checked
    boolean DoVRML; //True if the Export 3D+t data as a VRML file checkbox is checked


    //3D centring correction related variables----------------------------------
    int tmpx; //Temporary x value
    int tmpy; //Temporary y value
    int tmpz; //Temporary z value
    int tmpttl; //Temporary sum of all pixels' values in the signal box
    int tmppixval; //Intensity of the current pixel


    //Quantification related variables------------------------------------------
    int limsx1; //Left limit of the signal box
    int limsx2; //Right limit of the signal box
    int limsy1; //Upper limit of the signal box
    int limsy2; //Lower limit of the signal box
    int limsz1; //Top limit of the signal box
    int limsz2; //Bottom limit of the signal box
    double sizeSgl; //Number of voxel in the signal box
    int limbx1; //Left limit of the background box
    int limbx2; //Right limit of the background box
    int limby1; //Upper limit of the background box
    int limby2; //Lower limit of the background box
    int limbz1; //Top limit of the background box
    int limbz2; //Bottom limit of the background box
    double sizeBkgd; //Number of voxel in the background box
    double Qsgl; //Summed intensities of the voxels inside the signal box
    double Qbkgd; //Summed intensities of the voxels inside the background box
    double Qttl; //Summed intensities of the whole pixels in the stack at current time
    double Qttl0; //Summed intensities of the whole pixels in the stack at the first time of the current track
    double QSglBkgdCorr; //QSgl background corrected
    double QSglBkgdBleachCorr; //QSgl background and bleaching corrected


    //VRML export related variables---------------------------------------------
    String[] StaticArray={"None", "Trajectories", "Objects"}; //List of options in the static view choicelist
    String[] DynamicArray={"None", "Objects", "Objects & Static Trajectories", "Objects & Progressive Trajectories"}; //List of options in the dynamic view choicelist
    String Static; //Designation of the static view selected, to be added to the destination filename
    String Dynamic; //Designation of the dynamic view selected, to be added to the destination filename
    boolean StaticView; //True if a static view has to be generated
    boolean StaticViewObj; //True if a static view of the objects has to be generated
    boolean StaticViewTraj; //True if a static view of the trajectories has to be generated
    boolean DynamicView; //True if a dynamic view has to be generated
    boolean DynamicViewStaticTraj; //True if a dynamic view of the objects overlayed to a static view of trajectories has to be generated
    boolean DynamicViewDynamicTraj; //True if a dynamic view of the objects overlayed to a dynamic view of trajectories has to be generated
    String dirVRMLstat; //Path to save the static VRML view
    OutputStreamWriter oswStat; //Output file for VRML static view
    String dirVRMLdynam; //Path to save the dynamic VRML view
    OutputStreamWriter oswDynam; //Output file for VRML dynamic view
    String[] vrmlCol={"0 0 1", "0 1 0", "1 0 0", "0.5 1 1", "1 0.5 1","1 1 0","1 1 1"}; //Values for colors in the VRML file
    int x; //Variable to store x coordinate read from the 3D results table
    int y; //Variable to store y coordinate read from the 3D results table
    int z; //Variable to store z coordinate read from the 3D results table
    int xOld; //Variable to store previous x coordinate read from the 3D results table
    int yOld; //Variable to store previous y coordinate read from the 3D results table
    int zOld; //Variable to store previous z coordinate read from the 3D results table
    int [][] VRMLarray; //1st dimension: line nº from the 3D results table; 2nd dimension: 0-Tag (track nº/color); 1-time; 2-x, 3-y; 4-z
    int vrmlCount; //Number of tracks modulo 6: will define the color applied to the track
    double DistOfView; //Distance between the object and the camera in the VRML view
    double minTime; //Minimum timepoint where a track is started
    double maxTime; //Maximum timepoint where a track is ended
    int countBefore; //Difference between the current track startpoint and minTime
    int countAfter;//Difference between the current track endpoint and maxTime
    int countTtl; //Difference between countBefore and countAfter
    String key; //Defines the animation's keyframes
    int Tag; //Track number
    int TagOld; //Previous track number
    String point; //Stores the xyz coordinates (modified by calibration) of the current point from the current track
    int pointNb; //Number of points in the current track
    String pointKey; //Stores the xyz coordinates (modified by calibration) of each point from the current track
    String lastPoint; //Stores the xyz coordinates (modified by calibration) of the last point from the current track


    public Manual_Tracking() {

        //Interface setup ------------------------------------------------------
        super("Manual tracking");
        instance=this;
        panel = new Panel();
        panel.setLayout(new GridLayout(0,2, 5, 5));
        panel.setBackground(SystemColor.control);

        //---------------------------------Tracking
        butAdd = new Button("Add track");
        butAdd.addActionListener(this);
        panel.add(butAdd);

        butEnd = new Button("End track");
        butEnd.addActionListener(this);
        panel.add(butEnd);

        butDlp = new Button("Delete last point");
        butDlp.addActionListener(this);
        panel.add(butDlp);

        checkPath=new Checkbox("Show path ?", false);
        checkPath.addItemListener(this);
        panel.add(checkPath);

        butDel = new Button("Delete track nº");
        butDel.addActionListener(this);
        panel.add(butDel);

        trackdel = new Choice();
        panel.add(trackdel);

        butDelAll = new Button("Delete all tracks");
        butDelAll.addActionListener(this);
        panel.add(butDelAll);


        //---------------------------------Centring
        choicecent = new Choice();
        choicecent.add("Local maximum");
        choicecent.add("Local minimum");
        choicecent.add("Local barycentre");
        labelCorr=new Label();

        checkCent=new Checkbox("Use centring correction ?", false);
        checkCent.addItemListener(this);


        //---------------------------------Directionality
        butAddRef = new Button("Add reference");
        butAddRef.addActionListener(this);
        butDelRef = new Button("Delete reference");
        butDelRef.addActionListener(this);
        titleRef=new Label();
        titleRef.setText("No reference set");
        checkShowRef=new Checkbox("Show reference ?", false);
        checkShowRef.addItemListener(this);
        checkRef=new Checkbox("Use directionality ?", false);
        checkRef.addItemListener(this);

       //---------------------------------Drawing
        butOvd = new Button("Dots");
        butOvd.addActionListener(this);
//        panel.add(butOvd);
        butOvl = new Button("Progressive Lines");
        butOvl.addActionListener(this);
//        panel.add(butOvl);
        butOvdl = new Button("Dots & Lines");
        butOvdl.addActionListener(this);
//        panel.add(butOvdl);

        butOverdots = new Button("Overlay Dots");
        butOverdots.addActionListener(this);
//        panel.add(butOverdots);
        butOverlines = new Button("Overlay Lines");
        butOverlines.addActionListener(this);
//        panel.add(butOverlines);
        butOverboth = new Button("Overlay Dots & Lines");
        butOverboth.addActionListener(this);
//        panel.add(butOverboth);
        checkText=new Checkbox("Show text ?", false);
        checkText.addItemListener(this);

       //---------------------------------Load Previous Table/Parameters ?/Retrieve z
        butLoad = new Button("Load Previous Track File");
        butLoad.addActionListener(this);
//        panel.add(butLoad);
        checkParam=new Checkbox("Show parameters ?", true);
        checkParam.addItemListener(this);
//        panel.add(checkParam);
        butRetrieveZ = new Button("Retrieve Z Coordinates");
        butRetrieveZ.addActionListener(this);
//        panel.add(butRetrieveZ);

       //---------------------------------Setup of the hiddeable paramters menu
        labelEmpty1=new Label();
        labelEmpty2=new Label();
        labelEmpty3=new Label();
        labelEmpty4=new Label();
        labelEmpty5=new Label();
        labelEmpty6=new Label();
        labelEmpty7=new Label();
        labelEmpty8=new Label();
        labelEmpty9=new Label();


       //---------------------------------Parameters
        labelParam=new Label("Parameters :");
        labelTime=new Label("Time Interval :");
        caltfield = new TextField(Double.toString(calt));
//        panel.add(caltfield);
        choicecalt = new Choice();
        choicecalt.add("sec");
        choicecalt.add("min");
        choicecalt.add("unit");
        choicecalt.select("unit");
//        panel.add(choicecalt);

        labelxy=new Label("x/y calibration :");
//        panel.add(labelxy);
        calxyfield = new TextField(Double.toString(calxy));
//        panel.add(calxyfield);
        choicecalxy = new Choice();
        choicecalxy.add("nm");
        choicecalxy.add("µm");
        choicecalxy.add("unit");
        choicecalxy.select("unit");

        add(panel,BorderLayout.CENTER);
        pack();
        show();
        IJ.showProgress(2,1);
        rt=new ResultsTable();

    }

    public void itemStateChanged(ItemEvent e) {
        // Show/Hide the current path-------------------------------------------
        if (e.getSource() == checkPath) {
            if (checkPath.getState()) {img.setRoi(roi);
            } else {
                img.killRoi();
            }
            checkShowRef.setState(false);
        }

        // Enable/Disable the centring correction-------------------------------
        if (e.getSource() == checkCent) {
            if (!checkCent.getState()) commentCorr="";
            labelCorr.setText(commentCorr);
        }

        // Show/Hide reference position-----------------------------------------
        if (e.getSource() == checkShowRef) {
            if (checkShowRef.getState()) {
                if (!RefSet) {
                    IJ.showMessage("!!! Warning !!!", " No reference set:\nClick on 'Add reference' first !!!");
                    checkShowRef.setState(false);
                    return;
                }
                dotsize=(int) Tools.parseDouble(dotsizefield.getText());
                roiRef= new OvalRoi(refx-dotsize, refy-dotsize, 2*dotsize, 2*dotsize);
                img.setRoi(roiRef);
            } else {
                img.killRoi();
            }
            checkPath.setState(false);
        }

        // Show/Hide Parameters-------------------------------------------------
        if (e.getSource() == checkParam) {
            if (!checkParam.getState()){
                HideParam();
            }else{
                ShowParam();
            }
        }
    }

    public void actionPerformed(ActionEvent e) {
        // Button Add Track pressed---------------------------------------------
        if (e.getSource() == butAdd) {
            if (islistening){
                IJ.showMessage("This operation can't be completed:\na track is already being followed...");
                return;
            }
            HideParam();
            img=WindowManager.getCurrentImage();
            imgtitle = img.getTitle();
            if (imgtitle.indexOf(".")!=-1) imgtitle=imgtitle.substring(0,imgtitle.indexOf("."));
            calt=Tools.parseDouble(caltfield.getText());
            calxy=Tools.parseDouble(calxyfield.getText());
            if (calt==0 || calxy==0) {
                IJ.showMessage("Error", "Calibration values\n"+"should not be equal to zero !!!");
                ShowParam();
                return;
            }
            IJ.setTool(7);

            xRoi=new int[img.getStackSize()];
            yRoi=new int[img.getStackSize()];

            if (img==null){
                IJ.showMessage("Error", "Man,\n"+"You're in deep troubles:\n"+"no opened stack...");
                return;
            }

            win = img.getWindow();
            canvas=win.getCanvas();
            img.setSlice(1);

            NbPoint=1;
            IJ.showProgress(2,1);
            canvas.addMouseListener(this);
            islistening=true;
            return;
        }

        // Button Delete last point pressed-------------------------------------
        if (e.getSource() == butDlp) {
            gd = new GenericDialog("Delete last point");
            gd.addMessage("Are you sure you want to \n" + "delete last point ?");
            gd.showDialog();
            if (gd.wasCanceled()) return;

            //Create a temporary ResultTable and copy only the non deleted data
            rtmp=new ResultsTable();
            for (i=0; i<(rt.getCounter()); i++) {
                rtmp.incrementCounter();
//                for (j=0; j<7; j++) rtmp.addValue(j, rt.getValue(j,i));
                for (j=0; j<4; j++) rtmp.addValue(j, rt.getValue(j,i));
            }

            rt.reset();

            //Copy data back to original table except last point

            for (i=0; i<head.length; i++) rt.setHeading(i,head[i]);

            for (i=0; i<((rtmp.getCounter())-1); i++) {
                rt.incrementCounter();
//                for (j=0; j<7; j++) rt.addValue(j, rtmp.getValue(j,i));
                for (j=0; j<4; j++) rt.addValue(j, rtmp.getValue(j,i));
            }
            rt.show("Tracks");

            //Manage case where the deleted point is the last of a serie
            if (islistening==false) {
                Nbtrack--;
                trackdel.remove(""+(int) rt.getValue(0,rt.getCounter()-1));
                canvas.addMouseListener(this);
                islistening=true;
            }

            prevx=(int) rt.getValue(2, rt.getCounter()-1);
            prevy=(int) rt.getValue(3, rt.getCounter()-1);
            img.setSlice(((int) rt.getValue(1, rt.getCounter()-1))+1);
            IJ.showStatus("Last Point Deleted !");
        }

        // Button End Track pressed---------------------------------------------
        if (e.getSource() == butEnd) {
            trackdel.add(""+Nbtrack);
            Nbtrack++;
            canvas.removeMouseListener(this);
            islistening=false;
            IJ.showStatus("Tracking is over");
            IJ.showProgress(2,1);
            return;
        }

        // Button Del Track pressed---------------------------------------------
        if (e.getSource() == butDel) {
            canvas.removeMouseListener(this);
            islistening=false;
            int tracktodelete= (int) Tools.parseDouble(trackdel.getItem(trackdel.getSelectedIndex()));
            gd = new GenericDialog("Delete Track nº" + tracktodelete);
            gd.addMessage("Do you want to \n" + "delete track nº" + tracktodelete + " ?");
            gd.showDialog();
            if (gd.wasCanceled()) return;

            //Create a temporary ResultTable and copy only the non deleted data
            rtmp=new ResultsTable();
            for (i=0; i<(rt.getCounter()); i++) {
                int nbtrack=(int) rt.getValue(0,i);
                if(nbtrack!=tracktodelete){
                    rtmp.incrementCounter();
//                  for (j=0; j<7; j++) rtmp.addValue(j, rt.getValue(j,i));
                    for (j=0; j<4; j++) rtmp.addValue(j, rt.getValue(j,i));
                }
            }

            rt.reset();

            //Copy data back to original table

            for (i=0; i<head.length; i++) rt.setHeading(i,head[i]);

            for (i=0; i<(rtmp.getCounter()); i++) {
                rt.incrementCounter();
//                for (j=0; j<7; j++){
              for (j=0; j<4; j++){
                    if (j==0 & rtmp.getValue(0,i)>tracktodelete){
                        rt.addValue(j, rtmp.getValue(j,i)-1);
                    } else {
                        rt.addValue(j, rtmp.getValue(j,i));
                    }
                }
            }

            rt.show("Tracks");
            trackdel.removeAll();
            for (i=1;i<(rt.getValue(0,rt.getCounter()-1))+1;i++){
                trackdel.add(""+i);
            }
            IJ.showStatus("Track nº"+tracktodelete +" Deleted !");
            Nbtrack=((int) rt.getValue(0,rt.getCounter()-1))+1;
        }

        // Button Del All Tracks pressed----------------------------------------
        if (e.getSource() == butDelAll) {
            canvas.removeMouseListener(this);
            islistening=false;
            IJ.showProgress(2,1);
            IJ.showStatus("Tracking is over");
            gd = new GenericDialog("Delete All Tracks");
            gd.addMessage("Do you want to \n" + "delete all measurements ?");
            gd.showDialog();
            if (gd.wasCanceled()) return;
            rt.reset();
            rt.show("Tracks");
            trackdel.removeAll();
            IJ.showStatus("All Tracks Deleted !");
            Nbtrack=1;
            return;
        }

    }

    // Click on image-----------------------------------------------------------
    public void mouseReleased(MouseEvent m) {
        if (!islisteningRef){
            IJ.showProgress(img.getCurrentSlice()+1,img.getStackSize()+1);
            IJ.showStatus("Tracking slice "+(img.getCurrentSlice()+1)+" of "+(img.getStackSize()+1));
            if (Nbtrack==1 && NbPoint==1){
                for (i=0; i<head.length; i++) rt.setHeading(i,head[i]);
            }
        }

        img.killRoi();
        checkShowRef.setState(false);

        int x=m.getX();
        int y=m.getY();
        ox=canvas.offScreenX(x);
        oy=canvas.offScreenY(y);
        if (checkCent.getState()) Center2D();

        if (islisteningRef){
            canvas.removeMouseListener(this);
            islistening=false;
            islisteningRef=false;
            refx=ox;
            refy=oy;
            IJ.showStatus("Reference set to ("+refx+","+refy+")");
            titleRef.setText("Reference set to ("+refx+","+refy+")");
            RefSet=true;
            checkRef.setState(true);
            dotsize=(int) Tools.parseDouble(dotsizefield.getText());
            roiRef= new OvalRoi(refx-dotsize, refy-dotsize, 2*dotsize, 2*dotsize);
            img.setRoi(roiRef);
            checkShowRef.setState(true);
            return;
        }

        xRoi[NbPoint-1]=ox;
        yRoi[NbPoint-1]=oy;


        if (NbPoint==1){
            Distance=-1;
            Velocity=-1;
        } else {
            Distance=calxy*Math.sqrt(Math.pow((ox-prevx),2)+Math.pow((oy-prevy),2));
            Velocity=Distance/calt;
        }

        PixVal=img.getProcessor().getPixel(ox,oy);

        rt.incrementCounter();
        double[] doub={Nbtrack,(img.getCurrentSlice()),ox,oy};
        for (i=0; i<doub.length; i++) rt.addValue(i,doub[i]);
        rt.show("Tracks");


        if ((img.getCurrentSlice())<img.getStackSize()){
            NbPoint++;
            img.setSlice(img.getCurrentSlice()+1);
            if (Distance!=0) {
                pprevx=prevx;
                pprevy=prevy;
            }
            prevx=ox;
            prevy=oy;
            roi=new PolygonRoi(xRoi,yRoi,NbPoint-1,Roi.POLYLINE);
            if(checkPath.getState()) img.setRoi(roi);
        } else {
            trackdel.add(""+Nbtrack);
            Nbtrack++;
            img.setRoi(roi);
            canvas.removeMouseListener(this);
            islistening=false;
            checkCent.setState(false);
            IJ.showStatus("Tracking is over");
            return;
        }




    }

    public void mousePressed(MouseEvent m) {}
    public void mouseExited(MouseEvent m) {}
    public void mouseClicked(MouseEvent m) {}
    public void mouseEntered(MouseEvent m) {}

    void HideParam(){
    }

    void ShowParam(){
    }

    void Center2D(){
        int lim=(int)((Tools.parseDouble(centsize.getText()))/2);
        int pixval=img.getProcessor().getPixel(ox,oy);
        double xb=0;
        double yb=0;
        double sum=0;
        commentCorr="("+ox+","+oy+") > (";
        for (i=ox-lim; i<ox+lim+1; i++){
            for (j=oy-lim; j<oy+lim+1; j++){
                if (img.getProcessor().getPixel(i,j)>pixval && choicecent.getSelectedIndex()==0){
                    ox=i;
                    oy=j;
                    pixval=img.getProcessor().getPixel(ox,oy);
                }
                if (img.getProcessor().getPixel(i,j)<pixval && choicecent.getSelectedIndex()==1){
                    ox=i;
                    oy=j;
                    pixval=img.getProcessor().getPixel(ox,oy);
                }
                xb=xb+i*img.getProcessor().getPixel(i,j);
                yb=yb+j*img.getProcessor().getPixel(i,j);
                sum=sum+img.getProcessor().getPixel(i,j);
            }
        }
        xb=xb/sum;
        yb=yb/sum;
        if (choicecent.getSelectedIndex()==2){
            ox=(int)xb;
            oy=(int)yb;
        }
        commentCorr=commentCorr+ox+","+oy+")";
        labelCorr.setText(commentCorr);
    }

    void Dots(){

        dotsize=(int) Tools.parseDouble(dotsizefield.getText());
        j=0;
        int nbtrackold=1;
        for (i=0; i<(rt.getCounter()); i++) {
            int nbtrack=(int) rt.getValue(0,i);
            int nbslices=(int) rt.getValue(1,i);
            int cx=(int) rt.getValue(2,i);
            int cy=(int) rt.getValue(3,i);
            if ((nbtrack != nbtrackold)) j++;
            if (j>6) j=0;
            ImageProcessor ip= stack.getProcessor(nbslices);
            ip.setColor(col[j]);
            ip.setLineWidth(dotsize);
            ip.drawDot(cx, cy);
            if (checkText.getState()){
                Font font = new Font("SansSerif", Font.PLAIN, (int) Tools.parseDouble(fontsizefield.getText()));
                ip.setFont(font);
                ip.drawString(""+nbtrack, cx+(dotsize-5)/2, cy-(dotsize-5)/2);
            }
            nbtrackold=nbtrack;
        }

    }

    void ProLines(){

        linewidth=Tools.parseDouble(linewidthfield.getText());
        j=0;
        k=1;
        int cxold=0;
        int cyold=0;
        int nbtrackold=1;

        for (i=0; i<(rt.getCounter()); i++) {
            int nbtrack=(int) rt.getValue(0,i);
            int nbslices=(int) rt.getValue(1,i);
            int cx=(int) rt.getValue(2,i);
            int cy=(int) rt.getValue(3,i);
            int lim=img.getStackSize()+1;
            if ((nbtrack != nbtrackold)) {
                j++;
                k=1;
            }
            for (int n=nbtrack; n<(rt.getCounter());n++) {
                if ((int) (rt.getValue(0,n)) == nbtrack) lim=(int) rt.getValue(1,n);
            }

            if (j>6) j=0;
            for (int m=nbslices; m<lim+1;m++) {
                if (k==1){
                    cxold=cx;
                    cyold=cy;
                }

                ImageProcessor ip= stack.getProcessor(m);
                ip.setColor(col[j]);
                ip.setLineWidth((int) linewidth);
                ip.drawLine(cxold, cyold, cx, cy);
                nbtrackold=nbtrack;
                k++;
            }
            cxold=cx;
            cyold=cy;
        }
    }

}


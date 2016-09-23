//
//  ViewController.swift
//  ARToolKitiOS
//
//  Created by 藤澤研学生ユーザ on 2016/09/15.
//  Copyright © 2016年 藤澤研学生ユーザ. All rights reserved.
//

import UIKit
import AudioToolbox
import QuartzCore.QuartzCore
//import "ARView.h"
//@class ARView
class ViewController: UIViewController {
    let VIEW_SCALEFACTOR: Float = 1.0
    let VIEW_DISTANCE_MIN: Float = 5.0
    let VIEW_DISTANCE_MAX: Float = 2000.0
    
    internal var running: Bool = false
    internal var runLoopInterval: Int = 0
    internal var runLoopTimePrevious: Double = 0.0
    internal var videoPaused: Bool = false
    internal var paused: Bool = false
    
    //Video acquisition
    internal var gVid: UnsafeMutablePointer<AR2VideoParamT> = nil
    
    //Marker detection
    @objc internal var gARHandle: UnsafeMutablePointer<ARHandle> = nil
    internal var gARPattHandle: ARPattHandle?
    internal var gCallCountMarkerDetect: CLong = 0
    
    //Tansformation matrix retrieval
    internal var gAR3DHandle: UnsafeMutablePointer<AR3DHandle> = nil
    internal var gPatt_width: ARdouble = 0.0
    internal var gPatt_trans = [[ARdouble]]()//() ARdouble = 0.0 //= [3, 4] ToDo 配列にする
    internal var gPatt_found: Int32 = 0
    internal var gPatt_id: Int32 = 0
    internal var useContPoseEstimation: Bool = false
    
    //Drawing
    internal var gCparamLT: UnsafeMutablePointer<ARParamLT> = nil
    internal var glView: UnsafeMutablePointer<ARView> = nil
    internal var arglContextSettings: ARGL_CONTEXT_SETTINGS_REF?
    
    override func loadView() {
        var irisImage: String? = nil
        if (UIDevice.currentDevice().userInterfaceIdiom == .Pad) {
            irisImage = "Iris-iPad.png"
        } else {
            let result: CGSize = UIScreen.mainScreen().bounds.size
            if (result.height == 568) {
                irisImage = "Iris-568h.png" // iPhone 5, iPod touch 5th Gen, etc.
            } else { //result.height == 480
                irisImage = "Iris.png"
            }
        }
        let irisView = UIImageView(image: UIImage(named: irisImage!))
        irisView.userInteractionEnabled = true //get tap event.
        
        self.view = irisView
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        glView = nil
        gVid = nil
        gCparamLT = nil
        gARHandle = nil
        gARPattHandle = nil
        gCallCountMarkerDetect = 0
        gAR3DHandle = nil
        useContPoseEstimation = false
        arglContextSettings = nil
        running = false
        videoPaused = false
        runLoopTimePrevious = CFAbsoluteTimeGetCurrent()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.start()
    }
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return super.supportedInterfaceOrientations()// UIInterfaceOrientationMaskPortrait
    }
    func startRunLoop() {
        if (!running) {
            //After starting the video, new frames will invoke cameraVideoTookPicture:userData:.
            if (ar2VideoCapStart(gVid) != 0) {
              print("Error: Unable to begin camera data capture.");
              self.stop()
              return
            }
            running = true
        }
    }
    func stopRunLoop () {
        if (running) {
            ar2VideoCapStop(gVid)
            running = false
        }
    }
    private func setRunLoopInterval(interval: Int) {
        if (interval >= 1) {
            runLoopInterval = interval
            if (running) {
                self.stopRunLoop()
                self.startRunLoop()
            }
        }
    }
    
    func isPaused () -> Bool {
        if (!running) {
            return false
        }
        
        return videoPaused
    }
    
    func setPause (paused: Bool) {
        if (!running) {
            return
        }
        
        if (videoPaused != paused) {
            if (paused) {
                //ar2VideoCapStop(gVid)
            } else {
                //ar2VideoCapStart(gVid)
            }
            videoPaused = paused
            #if DEBUG
                print("Run loop was %s.\n", (paused ? "PAUSED" : "UNPAUSED"));
            #endif
        }
    }
    
    //startCallback(userDate)
    
    static func startCallback(userData: Void) {
        let vc: ViewController = ViewController(userData)
        vc.start2()
    }
    
    @IBAction func start() {
        var vconf: String = ""
        if (!(gVid = ar2VideoOpenAsync(vconf, startCallBack, self))) {
            print("Error: Unable to open connection to camera.");
            self.stop()
            return
        }
    }
    
    
    func start2 () {
        //Find the size of the window.
        var xsize: Int32
        var ysize: Int32
        if (ar2VideoGetSize(gVid, &xsize, &ysize) < 0) {
            print("Error: ar2VideoGetSize.\n")
            self.stop()
            return
        }
        
        //Get the format in which the camera is returning pixels.
        var pixFormat: AR_PIXEL_FORMAT = ar2VideoGetPixelFormat(gVid)
        if (pixFormat == AR_PIXEL_FORMAT_INVALID) {
            print("Error: Camera is using unsupported pixel format.\n")
            self.stop()
            return
        }
        
        // Work out if the front camera is being used. If it is, flip the viewing frustum for
        // 3D drawing.
        var flipV: Bool = false
        var frontCamera: UnsafeMutablePointer<Int32>
        let position :Int32 = Int32(AR_VIDEO_PARAM_IOS_CAMERA_POSITION)
        if (ar2VideoGetParami(gVid, position, frontCamera) >= 0) {
            if (frontCamera.memory == AR_VIDEO_IOS_CAMERA_POSITION_FRONT.rawValue) {
                flipV = true
            }
        }
        
        // Tell arVideo what the typical focal distance will be. Note that this does NOT
        // change the actual focus, but on devices with non-fixed focus, it lets arVideo
        // choose a better set of camera parameters.
        let focus :Int32 = Int32(AR_VIDEO_PARAM_IOS_FOCUS)
        ar2VideoSetParami(gVid, focus, Int32(AR_VIDEO_IOS_FOCUS_0_3M.rawValue)); // Default is 0.3 metres. See <AR/sys/videoiPhone.h> for allowable values.
        
        // Load the camera parameters, resize for the window and init.
        
        var cparam: ARParam?
        if (ar2VideoGetCParam(gVid, &cparam!) < 0) {
            var cparam_name: String = "Data2/camera_para.dat"
            print("Unable to automatically determine camera parameters. Using default.\n");
            if (arParamLoad(cparam_name, 1, &cparam!) < 0) {
                print("Error: Unable to load parameter file %s for camera.\n", cparam_name);
                self.stop()
                return
            }
        }
        if (cparam!.xsize != xsize || cparam!.ysize != ysize) {
            #if DEBUG
                fprintf(stdout, "*** Camera Parameter resized from %d, %d. ***\n", cparam.xsize, cparam.ysize)
            #endif
            arParamChangeSize(&cparam!, xsize, ysize, &cparam!)
        }
        #if DEBUG
            fprintf(stdout, "*** Camera Parameter ***\n")
            arParamDisp(&cparam)
        #endif
        
        gCparamLT = arParamLTCreate(&cparam!, AR_PARAM_LT_DEFAULT_OFFSET)
        if (gCparamLT == nil) {
            print("Error: arParamLTCreate.\n")
            self.stop()
            return
        }
        
        // AR init.
        gARHandle = arCreateHandle(gCparamLT)
        if (gARHandle == nil) {
            print("Error: arCreateHandle.\n");
            self.stop()
            return
        }
        if (arSetPixelFormat(gARHandle, pixFormat) < 0) {
            print("Error: arSetPixelFormat.\n");
            self.stop()
            return
        }
        var param = gCparamLT.memory.param
        gAR3DHandle = ar3DCreateHandle(&param)
        if (gAR3DHandle == nil) {
            print("Error: ar3DCreateHandle.\n");
            self.stop()
            return
        }
        
        // libARvideo on iPhone uses an underlying class called CameraVideo. Here, we
        // access the instance of this class to get/set some special types of information.
        let iPhone = gVid.memory.device.iPhone
        
        //var cameraVideo: UnsafePointer<AnyObject> = ar2VideoGetNativeVideoInstanceiPhone(iPhone)
        var cameraVideo = ar2VideoGetNativeVideoInstanceiPhone(iPhone)
        if (cameraVideo == nil) {
            print("Error: Unable to set up AR camera: missing CameraVideo instance.\n");
            self.stop()
            return
        }

        // The camera will be started by -startRunLoop.
        cameraVideo.tookPictureDelegate = self
        cameraVideo.tookPictureDelegateUserData = nil
        
        //Other ARToolKit setup
        arSetMarkerExtractionMode(gARHandle, AR_USE_TRACKING_HISTORY_V2)
        
        //Allocate the OpenGL view.
        glView.memory = ARView.init()
        glView.memory = ARView.init(frame: UIScreen.mainScreen().bounds,
                              pixelFormat: kEAGLColorFormatRGBA8,
                              depthFormat: kEAGLDepth16,
                              withStencil: false,
                              preserveBackbuffer: false)
        glView.memory.arViewController = self
        self.view.addSubview(glView.memory)
        
        // Create the OpenGL projection from the calibrated camera parameters.
        // If flipV is set, flip.
        var frustum = [GLfloat](count: 16,repeatedValue: 0.0)
        arglCameraFrustumRHf(&gCparamLT.memory.param, VIEW_DISTANCE_MIN, VIEW_DISTANCE_MAX, &frustum)
        glView.memory.cameraLens.memory = GLfloat(frustum[0])
        glView.memory.contentFlipV = flipV
        
        //Set up content positioning.
        glView.memory.contentScaleMode = ARViewContentScaleModeFill
        glView.memory.contentAlignMode = ARViewContentAlignModeCenter
        glView.memory.contentWidth = gARHandle.memory.xsize
        glView.memory.contentHeight = gARHandle.memory.ysize
        var isBackingTallerThanWide: Bool = (glView.memory.surfaceSize.height > glView.memory.surfaceSize.width)
        if (glView.memory.contentWidth > glView.memory.contentHeight) {
            glView.memory.contentRotate90 = isBackingTallerThanWide
        } else {
            glView.memory.contentRotate90 = !isBackingTallerThanWide
        }
#if DEBUG
        print("[ARViewController start] content %dx%d (wxh) will display in GL context %dx%d%s.\n", glView.memory.contentWidth, glView.memory.contentHeight, Int(glView.memory.surfaceSize.width)!, Int(glView.memory.surfaceSize.height)!, (glView.memory.contentRotate90 ? " rotated" : ""));
#endif
        //Setup ARGL to deaw the background video.
        arglContextSettings = arglSetupForCurrentContext(&gCparamLT.memory.param , pixFormat)
        
        let temp: Int8
        if (glView.memory.contentWidth > glView.memory.contentHeight) {
            if (isBackingTallerThanWide) {
                temp = 1
            } else {
                temp = 0
            }
        } else {
            if (isBackingTallerThanWide) {
                temp = 1
            } else {
                temp = 0
            }
        }
        arglSetRotate90(arglContextSettings!, temp)
        
        if (flipV) {
            arglSetFlipV(arglContextSettings!, 1)
        }
        var width :Int32
        var height: Int32
        ar2VideoGetBufferSize(gVid, &width, &height)
        arglPixelBufferSizeSet(arglContextSettings!, width, height)
        
        //Prepare ARToolKit to load patterns
        gARPattHandle = arPattCreateHandle().memory
        if (gARPattHandle == nil) {
            print("Error: arPattCreateHandle.")
            self.stop()
            return
        }
        arPattAttach(gARHandle, &gARPattHandle!)
        
        //Load marker(s)
        //Loading only 1 pattern in tis example.
        let patt_name_string = "Data2/hiro.patt"
        let patt_name_utf8string = (patt_name_string as NSString).UTF8String
        let patt_name = UnsafeMutablePointer<Int8>(patt_name_utf8string)
        gPatt_id = arPattLoad(&gARPattHandle!, patt_name)
        if (gPatt_id < 0) {
            print("Error loading pattern file %s.\n", patt_name)
            self.stop()
            return
        }
        gPatt_width = 40.0
        gPatt_found = 0 //false
        
        //For FPS statistics
        arUtilTimerReset()
        gCallCountMarkerDetect = 0
        
        //Create our runloop timer
        self.setRunLoopInterval(2)
        self.startRunLoop()
    }
    
    func cameraVideoTookPicture (sender : AnyObject, userData: UnsafeMutablePointer<Void>) {
        let buffer: UnsafeMutablePointer<AR2VideoBufferT> = ar2VideoGetImage(gVid)
        if (buffer != nil) {
            self.processFrame(buffer)
        }
    }
    
    func processFrame (buffer: UnsafeMutablePointer<AR2VideoBufferT>) {
        var err: ARdouble
        var j: Int32
        var k: Int32
        
        if (buffer != nil) {
            //Upload the frame to OpenGL.
            if (buffer.memory.bufPlaneCount == 2) {
                arglPixelBufferDataUploadBiPlanar(arglContextSettings!, buffer.memory.bufPlanes[0], buffer.memory.bufPlanes[1])
            } else {
                arglPixelBufferDataUploadBiPlanar(arglContextSettings!, buffer.memory.buff, nil)
            }
            
            gCallCountMarkerDetect += 1 //Increment ARToolKit FPS counter.
#if DEBUG
            print("video frame %ld.\n", gCallCountMarkerDetect);
#endif
#if DEBUG
            if (gCallCountMarkerDetect % 150 == 0) {
                print("*** Camera - %f (frame/sec)\n", Double(doublegCallCountMarkerDetect/arUtilTimer())!);
                gCallCountMarkerDetect = 0;
                arUtilTimerReset();
            }
#endif
            // Detect the markers in the video frame.
            if (arDetectMarker(gARHandle, buffer.memory.buff) < 0) {
                return
            }
#if DEBUG
            print("found %d marker(s).\n", gARHandle.memory.marker_num)
#endif
            // Check through the marker_info array for highest confidence
            // visible marker matching our preferred pattern.
            k = -1;
            /*for markerInfo in gARHandle.memory.markerInfo {
                
            }
            for (j = 0; j < gARHandle.memory.marker_num; j += 1) {
                let markerInfo = gARHandle.memory.makerInfo[j]
                if (gARHandle.memory.markerInfo[j].id == gPatt_id) {
                    if (k == -1) {
                        k = j // First marker detected.
                    }
                    else if (gARHandle.memory.markerInfo[j].cf > gARHandle.memory.markerInfo[k].cf) {
                        k = j; // Higher confidence marker detected.
                    }
                }
            }*/
            
            if (k != -1) {
#if DEBUG
                print("marker %d matched pattern %d.\n", k, gPatt_id);
#endif
                // Get the transformation between the marker and the real camera into gPatt_trans.
                if (gPatt_found > 0 && useContPoseEstimation) {
                    err = arGetTransMatSquareCont(gAR3DHandle, &(gARHandle.memory.markerInfo[k]), gPatt_trans, gPatt_width, gPatt_trans);
                } else {
                    err = arGetTransMatSquare(gAR3DHandle, &(gARHandle.memory.markerInfo[k]), gPatt_width, gPatt_trans);
                }
                var modelview = [Float](count: 16,repeatedValue: 0.0) // We have a new pose, so set that.
#if ARDOUBLE_IS_FLOAT
                arglCameraViewRHf(gPatt_trans, modelview, VIEW_SCALEFACTOR);
#else
                var patt_transf = [[Float]](count: 3, repeatedValue: [Float](count: 4, repeatedValue: 0))
                for i in 0..<3 {
                    for j in 0..<4 {
                        patt_transf[i][j] = Float(gPatt_trans[i][j])
                    }
                }
                arglCameraViewRHf(&patt_transf, modelview, VIEW_SCALEFACTOR)

#endif
                gPatt_found = 1 //true
                glView.memory.cameraPose = modelview
            } else {
                gPatt_found = 0 //false
                glView.memory.cameraPose = nil
            }
            
            // Get current time (units = seconds).
            var runLoopTimeNow: NSTimeInterval
            runLoopTimeNow = CFAbsoluteTimeGetCurrent();
            glView.memory.updateWithTimeDelta(runLoopTimeNow - runLoopTimePrevious)

            // The display has changed.
            glView.memory.drawView(self)
            
            // Save timestamp for next loop.
            runLoopTimePrevious = runLoopTimeNow;
        }
    }
    //private func ar2VideoGetNativeVideoInstanceiPhone(vid : _AR2VideoParamiPhoneT) -> CameraVideo? {
      /*if (!vid) return (nil);
      if (vid->itsAMovie) return (vid->movieVideo);
      else return (vid->cameraVideo);*/
    //}
    
    func stop () {
        self.stopRunLoop()
        if (arglContextSettings != nil) {
            arglCleanup(arglContextSettings!)
            arglContextSettings = nil
        }
        glView.memory.removeFromSuperview() // Will result in glView being released.
        glView = nil
        
        if (gARHandle != nil) {
            arPattDetach(gARHandle)
        }
        if (gARPattHandle != nil) {
            arPattDeleteHandle(&gARPattHandle!)
            gARPattHandle = nil
        }
        if (gAR3DHandle != nil) {
            ar3DDeleteHandle(&gAR3DHandle)
        }
        if (gARHandle != nil) {
            arDeleteHandle(gARHandle)
            gARHandle = nil
        }
        arParamLTFree(&gCparamLT)
        if (gVid != nil) {
            ar2VideoClose(gVid)
            gVid = nil
        }
    }
    
    override func didReceiveMemoryWarning () {
        // Releases the view if it doesn't have a superview
        super.didReceiveMemoryWarning()
        
        // Release any cached data, images, etc that aren't in use.
    }
    
    override func viewWillDisappear (animated: Bool) {
        self.stop()
        super.viewWillDisappear(animated)
    }
    
    deinit {
        //super.dein
    }
    
    //ARToolKit-specific methods.
    func markersHaveWhiteBorders () -> Bool {
        var mode :Int32
        arGetLabelingMode(gARHandle, &mode)
        return (mode == AR_LABELING_WHITE_REGION)
    }
    
    func setMarkersHaveWhiteBorders (markersHaveWhiteBorders: Bool) {
        arSetLabelingMode(gARHandle, (markersHaveWhiteBorders ? AR_LABELING_WHITE_REGION : AR_LABELING_BLACK_REGION))
    }
    
    // Call this method to take a snapshot of the ARView.
    // Once the image is ready, tookSnapshot:forview: will be called.
    func takeSnapshot() {
    // We will need to wait for OpenGL rendering to complete.
    glView.memory.tookSnapshotDelegate = self
    glView.memory.takeSnapshot()
    }
    
    // Here you can choose what to do with the image.
    // We will save it to the iOS camera roll.
    func tookSnapshot(snapshot: UnsafePointer<UIImage>, forView view: UnsafePointer<EAGLView>) {
    // First though, unset ourselves as delegate.
        glView.memory.tookSnapshotDelegate = nil
    
    // Write image to camera roll.
        UIImageWriteToSavedPhotosAlbum(snapshot.memory, self, #selector(ViewController.image(_:didFinishSavingWithError:error:)), nil);
    }
    
    // Let the user know that the image was saved by playing a shutter sound,
    // or if there was an error, put up an alert.
    func image(image: UIImage, didFinishSavingWithError error: UnsafePointer<NSError>, error contextInfo: UnsafePointer<Void>) {
        if (error == nil) {
            var shutterSound: SystemSoundID
            let cfurf: CFURL = NSBundle.mainBundle().URLForResource("slr_camera_shutter", withExtension: "wav")!
            AudioServicesCreateSystemSoundID(cfurf, &shutterSound);
            AudioServicesPlaySystemSound(shutterSound);
        } else {
            var titleString: NSString = "Error saving screenshot"
            var messageString: NSString = error.memory.localizedDescription
            var moreString: NSString = (error.memory.localizedFailureReason != nil) ? error.memory.localizedFailureReason! : NSLocalizedString("Please try again.", comment: "")
            messageString = NSString.localizedStringWithFormat((messageString as String) + ". " + (moreString as String))
            var alertView : UnsafePointer<UIAlertView> = UIAlertView.init(title: titleString as String, message: messageString as String, delegate: self, cancelButtonTitle: "OK", otherButtonTitles: nil)
            alertView.memory.show()
        }
    }
    
}




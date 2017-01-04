//
//  ViewController.swift
//  ARToolKitiOS
//
//  Created by 藤澤研学生ユーザ on 2016/09/15.
//  Copyright © 2016年 藤澤研学生ユーザ. All rights reserved.
//

import UIKit
//import AVFoundation
import AudioToolbox
import QuartzCore
//@class ARView
class ARViewController: UIViewController, UIAlertViewDelegate, CameraVideoTookPictureDelegate, EAGLViewTookSnapshotDelegate{
    let VIEW_SCALEFACTOR: Float = 1.0
    let VIEW_DISTANCE_MIN: Float = 5.0
    let VIEW_DISTANCE_MAX: Float = 2000.0
    
    internal var running: Bool = false
    internal var runLoopInterval: Int = 0
    internal var runLoopTimePrevious: Double = 0.0
    internal var videoPaused: Bool = false
    internal var paused: Bool = false
    
    //Video acquisition
    internal var gVid: UnsafeMutablePointer<AR2VideoParamT>? = nil
    
    //Marker detection
    
    //var gARHandle: UnsafeMutablePointer<ARHandle>? = ARPointerBridge().gARHandle
    //var arPointerBridge = ARPointerBridge()
    internal var gARHandle: UnsafeMutablePointer<ARHandle>? = nil
    internal var gARPattHandle: ARPattHandle?
    internal var gCallCountMarkerDetect: CLong = 0
    
    //Tansformation matrix retrieval
    internal var gAR3DHandle: UnsafeMutablePointer<AR3DHandle>? = nil
    internal var gPatt_width: ARdouble = 0.0
    internal var gPatt_trans = [(ARdouble, ARdouble, ARdouble, ARdouble)](repeating: (0, 0, 0, 0), count: 3)
    internal var gPatt_found: Int32 = 0
    internal var gPatt_id: Int32 = 0
    internal var useContPoseEstimation: Bool = false
    
    //Drawing
    internal var gCparamLT: UnsafeMutablePointer<ARParamLT>? = nil
    var glView: ARView? = nil
    internal var arglContextSettings: ARGL_CONTEXT_SETTINGS_REF? = nil
    
    override func loadView() {
        var irisImage: String? = nil
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            irisImage = "Iris-iPad.png"
        } else {
            let result: CGSize = UIScreen.main.bounds.size
            if (result.height == 568) {
                irisImage = "Iris-568h.png" // iPhone 5, iPod touch 5th Gen, etc.
            } else { //result.height == 480
                irisImage = "Iris.png"
            }
        }
        let irisView = UIImageView(image: UIImage(named: irisImage!))
        irisView.isUserInteractionEnabled = true //get tap event.
        
        self.view = irisView
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        glView = nil
        gVid = nil
        //arPointerBridge.setAR2VideoParamT(nil)
        gCparamLT = nil
        //arPointerBridge.setARHandle(nil)
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.start()
    }
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return super.supportedInterfaceOrientations// UIInterfaceOrientationMaskPortrait
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
    fileprivate func setRunLoopInterval(_ interval: Int) {
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
    
    func setPause (_ paused: Bool) {
        if (!running) {
            return
        }
        
        if (videoPaused != paused) {
            if (paused) {
                ar2VideoCapStop(gVid)
            } else {
                ar2VideoCapStart(gVid)
            }
            videoPaused = paused
            #if DEBUG
                print("Run loop was %s.\n", (paused ? "PAUSED" : "UNPAUSED"));
            #endif
        }
    }
    
    let startCallback: @convention(c)(UnsafeMutableRawPointer?) -> Void = {(userData) in
        let temp:ARViewController = unsafeBitCast(userData, to: ARViewController.self)
        //var vc: UnsafeMutablePointer<ARViewController> = unsafeBitCast(userData, to: UnsafeMutablePointer<ARViewController>.self)
        //vc.pointee.start2()
        temp.start2()
    }
    
    /*func startCallback(_ userData: UnsafeMutableRawPointer) {
        let vc: UnsafeMutablePointer<ARViewController> = unsafeBitCast(userData, to: UnsafeMutablePointer<ARViewController>.self)
        vc.pointee.start2()
    }*/
    
    @IBAction func start() {
        let vconf: String = ""
        let ref: UnsafeMutableRawPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        
        //arPointerBridge.gVid = ar2VideoOpenAsync(vconf, startCallback, ref)
        //arPointerBridge.setAR2VideoParamT(ar2VideoOpenAsync(vconf, startCallback, ref))
        /*if (arPointerBridge.gVid == nil) {
            print("false");
            //ar2VideoOpenAsync(<#T##config: UnsafePointer<Int8>##UnsafePointer<Int8>#>, <#T##callback: ((UnsafeMutablePointer<Void>) -> Void)!##((UnsafeMutablePointer<Void>) -> Void)!##(UnsafeMutablePointer<Void>) -> Void#>, <#T##userdata: UnsafeMutablePointer<Void>##UnsafeMutablePointer<Void>#>)
            print("Error: Unable to open connection to camera.");
            self.stop()
            return
        }*/
        gVid = ar2VideoOpenAsync(vconf, startCallback, ref)
        if (gVid == nil) {
            //ar2VideoOpenAsync(<#T##config: UnsafePointer<Int8>##UnsafePointer<Int8>#>, <#T##callback: ((UnsafeMutablePointer<Void>) -> Void)!##((UnsafeMutablePointer<Void>) -> Void)!##(UnsafeMutablePointer<Void>) -> Void#>, <#T##userdata: UnsafeMutablePointer<Void>##UnsafeMutablePointer<Void>#>)
            print("Error: Unable to open connection to camera.");
            self.stop()
            return
        }
    }
    
    
    func start2 () {
        print("play start2.")
        //Find the size of the window.
        var xsize: Int32 = 0
        var ysize: Int32 = 0
        if (ar2VideoGetSize(gVid, &xsize, &ysize) < 0) {
            print("Error: ar2VideoGetSize.\n")
            self.stop()
            return
        }
        
        //Get the format in which the camera is returning pixels.
        let pixFormat: AR_PIXEL_FORMAT = ar2VideoGetPixelFormat(gVid)
        if (pixFormat == AR_PIXEL_FORMAT_INVALID) {
            print("Error: Camera is using unsupported pixel format.\n")
            //self.stop()
            return
        }
        
        // Work out if the front camera is being used. If it is, flip the viewing frustum for
        // 3D drawing.
        var flipV: Bool = false
        var frontCamera: Int32 = 0
        if (ar2VideoGetParami(gVid, Int32(AR_VIDEO_PARAM_IOS_CAMERA_POSITION), &frontCamera) >= 0) {
            if (frontCamera == AR_VIDEO_IOS_CAMERA_POSITION_FRONT.rawValue) {
                flipV = true
            }
        }
        
        // Tell arVideo what the typical focal distance will be. Note that this does NOT
        // change the actual focus, but on devices with non-fixed focus, it lets arVideo
        // choose a better set of camera parameters.
        let focus :Int32 = Int32(AR_VIDEO_PARAM_IOS_FOCUS)
        ar2VideoSetParami(gVid, focus, Int32(AR_VIDEO_IOS_FOCUS_0_3M.rawValue)); // Default is 0.3 metres. See <AR/sys/videoiPhone.h> for allowable values.
        
        // Load the camera parameters, resize for the window and init.
        
        var cparam: ARParam = ARParam()
        if (ar2VideoGetCParam(gVid, &cparam) < 0) {
            var cparam_name: String = "Data2/camera_para.dat"
            print("Unable to automatically determine camera parameters. Using default.\n");
            if (arParamLoadFromBuffer(cparam_name, 1, &cparam) < 0) {
                print("Error: Unable to load parameter file %s for camera.\n", cparam_name);
                self.stop()
                return
            }
        }
        if (cparam.xsize != xsize || cparam.ysize != ysize) {
            #if DEBUG
                fprintf(stdout, "*** Camera Parameter resized from %d, %d. ***\n", cparam.xsize, cparam.ysize)
            #endif
            arParamChangeSize(&cparam, xsize, ysize, &cparam)
        }
        #if DEBUG
            fprintf(stdout, "*** Camera Parameter ***\n")
            arParamDisp(&cparam)
        #endif
        
        gCparamLT = arParamLTCreate(&cparam, AR_PARAM_LT_DEFAULT_OFFSET)
        if (gCparamLT == nil) {
            print("Error: arParamLTCreate.\n")
            self.stop()
            return
        }
        
        // AR init.
        gARHandle = arCreateHandle(gCparamLT);
        if (gARHandle == nil) {
          print("arHandle nil.\n");
        }
        
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
        gAR3DHandle = ar3DCreateHandle(&gCparamLT!.pointee.param)
        if (gAR3DHandle == nil) {
            print("Error: ar3DCreateHandle.\n");
            self.stop()
            return
        }
        
        // libARvideo on iPhone uses an underlying class called CameraVideo. Here, we
        // access the instance of this class to get/set some special types of information.
        let iPhone = gVid?.pointee.device.iPhone
        let cameraVideo : CameraVideo? = ar2VideoGetNativeVideoInstanceiPhone(iPhone) as! CameraVideo?

        if (cameraVideo == nil) {
            print("Error: Unable to set up AR camera: missing CameraVideo instance.\n");
            self.stop()
            return
        }
        
        // The camera will be started by -startRunLoop.
        // FIXME Movie Video の場合
        cameraVideo!.tookPictureDelegate = self
        cameraVideo!.tookPictureDelegateUserData = nil
        //var camera : CameraVideo? = cameraVideo as? CameraVideo
        //camera!.tookPictureDelegate = self
        //camera!.tookPictureDelegateUserData = nil
        
        //Other ARToolKit setup
        arSetMarkerExtractionMode(gARHandle!, AR_USE_TRACKING_HISTORY_V2)
        
        //Allocate the OpenGL view.
        //glView?.pointee = ARView.init()
        glView = ARView.init(frame: UIScreen.main.bounds,
                                    pixelFormat: kEAGLColorFormatRGBA8,
                                    depthFormat: kEAGLDepth16,
                                    withStencil: false,
                                    preserveBackbuffer: false)
        glView!.arViewController = self
        self.view.addSubview(glView!)
        //self.view.addSubview(<#T##view: UIView##UIView#>)
        // Create the OpenGL projection from the calibrated camera parameters.
        // If flipV is set, flip.
        var frustum = [GLfloat](repeating: 0.0,count: 16)
        arglCameraFrustumRHf(&gCparamLT!.pointee.param, VIEW_DISTANCE_MIN, VIEW_DISTANCE_MAX, &frustum)
        glView!.cameraLens.pointee = GLfloat(frustum[0])
        glView!.contentFlipV = flipV
        
        //Set up content positioning.
        glView!.contentScaleMode = ARViewContentScaleModeFill
        glView!.contentAlignMode = ARViewContentAlignModeCenter
        glView!.contentWidth = (gARHandle?.pointee.xsize)!
        glView!.contentHeight = (gARHandle?.pointee.ysize)!

        var isBackingTallerThanWide: Bool = (glView!.surfaceSize.height > glView!.surfaceSize.width)
        if (glView!.contentWidth > glView!.contentHeight) {
            glView!.contentRotate90 = isBackingTallerThanWide
        } else {
            glView!.contentRotate90 = !isBackingTallerThanWide
        }
        #if DEBUG
            print("[ARViewController start] content ",glView!.contentWidth, glView!.contentHeight," (wxh) will display in GL context ",  Int(glView!.surfaceSize.width), Int(glView!.surfaceSize.height), (glView!.contentRotate90 ? " rotated" : ""),"\n");
        #endif
        //Setup ARGL to deaw the background video.
        arglContextSettings = arglSetupForCurrentContext(&gCparamLT!.pointee.param, pixFormat)
        
        let temp: Int8
        if (glView!.contentWidth > glView!.contentHeight) {
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
        var width :Int32 = 0
        var height: Int32 = 0
        ar2VideoGetBufferSize(gVid, &width, &height)
        arglPixelBufferSizeSet(arglContextSettings!, width, height)
        
        //Prepare ARToolKit to load patterns
        gARPattHandle = arPattCreateHandle().pointee
        if (gARPattHandle == nil) {
            print("Error: arPattCreateHandle.")
            self.stop()
            return
        }
        arPattAttach(gARHandle, &gARPattHandle!)
        
        //Load marker(s)
        //Loading only 1 pattern in tis example.
        let patt_name_string = "Data2/hiro.patt"
        let patt_name_utf8string = (patt_name_string as NSString).utf8String
        let patt_name = UnsafeMutablePointer<Int8>(mutating: patt_name_utf8string)
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
    
    func cameraVideoTookPicture(_ sender: Any, userData data: UnsafeMutableRawPointer) {
        let buffer: UnsafeMutablePointer<AR2VideoBufferT>? = ar2VideoGetImage(gVid)
        if (buffer != nil) {
            self.processFrame(buffer)
        }
    }
    
    func processFrame (_ buffer: UnsafeMutablePointer<AR2VideoBufferT>?) {
        var err: ARdouble
        //var j: Int32
        var k: Int32
        
        if (buffer != nil) {
            //Upload the frame to OpenGL.
            if (buffer!.pointee.bufPlaneCount == 2) {
                arglPixelBufferDataUploadBiPlanar(arglContextSettings!, buffer!.pointee.bufPlanes[0], buffer!.pointee.bufPlanes[1])
            } else {
                arglPixelBufferDataUploadBiPlanar(arglContextSettings!, buffer!.pointee.buff, nil)
            }
            
            gCallCountMarkerDetect += 1 //Increment ARToolKit FPS counter.
            #if DEBUG
                print("video frame ",gCallCountMarkerDetect,"\n");
            #endif
            #if DEBUG
                if (gCallCountMarkerDetect % 150 == 0) {
                    print("*** Camera - %f (frame/sec)\n", Double(doublegCallCountMarkerDetect/arUtilTimer())!);
                    gCallCountMarkerDetect = 0;
                    arUtilTimerReset();
                }
            #endif
            // Detect the markers in the video frame.
            if (arDetectMarker(gARHandle!, buffer!.pointee.buff) < 0) {
                return
            }
            #if DEBUG
                print("found %d marker(s).\n", gARHandle.memory.marker_num)
            #endif
            // Check through the marker_info array for highest confidence
            // visible marker matching our preferred pattern.
            k = -1;
            for j in 0..<gARHandle!.pointee.marker_num {
                if (getId(j) == gPatt_id) {
                    if (k == -1) {
                        k = j;
                    }
                    else if (getCf(j) > getCf(k)) {
                        k = j;
                    }
                }
            }
            
            if (k != -1) {
                #if DEBUG
                    
                    print("marker %d matched pattern %d.\n", k, gPatt_id);
                #endif
                // Get the transformation between the marker and the real camera into gPatt_trans.
                //var arrayPointer: UnsafeMutablePointer<(ARdouble, ARdouble, ARdouble, ARdouble)> = &gPatt_trans[0]
                if (gPatt_found > 0 && useContPoseEstimation) {
                    err = arGetTransMatSquareCont(gAR3DHandle, arGetThisMarker(gARHandle!, k), &gPatt_trans, gPatt_width, &gPatt_trans);
                } else {
                    err = arGetTransMatSquare(gAR3DHandle, arGetThisMarker(gARHandle!, k), gPatt_width, &gPatt_trans);
                }
                var modelview = [Float](repeating: 0.0,count: 16) // We have a new pose, so set that.
                #if ARDOUBLE_IS_FLOAT
                    arglCameraViewRHf(gPatt_trans, modelview, VIEW_SCALEFACTOR);
                #else
                    var patt_transf = [(Float, Float, Float, Float)](repeating: (0, 0, 0, 0), count: 3)
                    for i in 0..<3 {
                        for j in 0..<4 {
                            switch (j) {
                            case 0:  patt_transf[i].0 = Float(gPatt_trans[i].0);
                            case 1:  patt_transf[i].1 = Float(gPatt_trans[i].1);
                            case 2:  patt_transf[i].2 = Float(gPatt_trans[i].2);
                            case 3:  patt_transf[i].3 = Float(gPatt_trans[i].3);
                            default: break
                            }
                        }
                    }
                    arglCameraViewRHf(&patt_transf, &modelview, VIEW_SCALEFACTOR)
                    
                #endif
                gPatt_found = 1 //true
                glView!.setCameraPose(&modelview)
            } else {
                gPatt_found = 0 //false
                glView!.setCameraPose(nil)
                //glView!.cameraPose = nil
            }
            
            // Get current time (units = seconds).
            var runLoopTimeNow: TimeInterval
            runLoopTimeNow = CFAbsoluteTimeGetCurrent()
            glView!.update(withTimeDelta: (runLoopTimeNow - runLoopTimePrevious))
            
            // The display has changed.
            //FIXME Current draw framebuffer is invalid.
            glView!.draw(self)

            // Save timestamp for next loop.
            runLoopTimePrevious = runLoopTimeNow;
        }
    }
    
    func stop () {
        self.stopRunLoop()
        if (arglContextSettings != nil) {
            arglCleanup(arglContextSettings!)
            arglContextSettings = nil
        }
        glView!.removeFromSuperview() // Will result in glView being released.
        glView = nil
        
        if (gARHandle != nil) {
            arPattDetach(gARHandle!)
        }
        if (gARPattHandle != nil) {
            arPattDeleteHandle(&gARPattHandle!)
            gARPattHandle = nil
        }
        if (gAR3DHandle != nil) {
            ar3DDeleteHandle(&gAR3DHandle)
        }
        if (gARHandle != nil) {
            arDeleteHandle(gARHandle!)
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
    
    override func viewWillDisappear (_ animated: Bool) {
        self.stop()
        super.viewWillDisappear(animated)
    }
        
    //ARToolKit-specific methods.
    func markersHaveWhiteBorders () -> Bool {
        var mode :Int32 = 0
        arGetLabelingMode(gARHandle!, &mode)
        return (mode == AR_LABELING_WHITE_REGION)
    }
    
    func setMarkersHaveWhiteBorders (_ markersHaveWhiteBorders: Bool) {
        arSetLabelingMode(gARHandle!, (markersHaveWhiteBorders ? AR_LABELING_WHITE_REGION : AR_LABELING_BLACK_REGION))
    }
    
    // Call this method to take a snapshot of the ARView.
    // Once the image is ready, tookSnapshot:forview: will be called.
    func takeSnapshot() {
        // We will need to wait for OpenGL rendering to complete.
        glView!.tookSnapshotDelegate = self
        glView!.takeSnapshot()
    }
    
    // Here you can choose what to do with the image.
    // We will save it to the iOS camera roll.
    func tookSnapshot(_ image: UIImage!, for view: EAGLView!) {
        // First though, unset ourselves as delegate.
        glView!.tookSnapshotDelegate = nil
        
        // Write image to camera roll.
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(ARViewController.image(_:didFinishSavingWithError:error:)), nil);
    }
    
    // Let the user know that the image was saved by playing a shutter sound,
    // or if there was an error, put up an alert.
    func image(_ image: UIImage, didFinishSavingWithError error: UnsafePointer<NSError>?, error contextInfo: UnsafeRawPointer) {
        if (error == nil) {
            var shutterSound: SystemSoundID = 0
            let cfurf: CFURL = Bundle.main.url(forResource: "slr_camera_shutter", withExtension: "wav")! as CFURL
            AudioServicesCreateSystemSoundID(cfurf, &shutterSound);
            AudioServicesPlaySystemSound(shutterSound);
        } else {
            var titleString: String = "Error saving screenshot"
            var messageString: String = error!.pointee.localizedDescription as String
            var moreString: String = (error!.pointee.localizedFailureReason != nil) ? error!.pointee.localizedFailureReason! : NSLocalizedString("Please try again.", comment: "") as String
            messageString = String.localizedStringWithFormat((messageString as String) + ". " + (moreString as String))
            var alertView : UIAlertView = UIAlertView.init(title: titleString as String, message: messageString as String, delegate: self, cancelButtonTitle: "OK")
            alertView.show()
        }
    }
    
    func arrayFromTuple<T, U>(tuple: T) -> [U] {
        return Mirror(reflecting: tuple).children.map{ $0.value as! U}
    }

    func getId(_ num: Int32) -> Int32 {
        switch num {
        case 0: return gARHandle!.pointee.markerInfo.0.id;
        case 1: return gARHandle!.pointee.markerInfo.1.id;
        case 2: return gARHandle!.pointee.markerInfo.2.id;
        case 3: return gARHandle!.pointee.markerInfo.3.id;
        case 4: return gARHandle!.pointee.markerInfo.4.id;
        case 5: return gARHandle!.pointee.markerInfo.5.id;
        case 6: return gARHandle!.pointee.markerInfo.6.id;
        case 7: return gARHandle!.pointee.markerInfo.7.id;
        case 8: return gARHandle!.pointee.markerInfo.8.id;
        case 9: return gARHandle!.pointee.markerInfo.9.id;

        case 10: return gARHandle!.pointee.markerInfo.10.id;
        case 11: return gARHandle!.pointee.markerInfo.11.id;
        case 12: return gARHandle!.pointee.markerInfo.12.id;
        case 13: return gARHandle!.pointee.markerInfo.13.id;
        case 14: return gARHandle!.pointee.markerInfo.14.id;
        case 15: return gARHandle!.pointee.markerInfo.15.id;
        case 16: return gARHandle!.pointee.markerInfo.16.id;
        case 17: return gARHandle!.pointee.markerInfo.17.id;
        case 18: return gARHandle!.pointee.markerInfo.18.id;
        case 19: return gARHandle!.pointee.markerInfo.19.id;

        case 20: return gARHandle!.pointee.markerInfo.20.id;
        case 21: return gARHandle!.pointee.markerInfo.21.id;
        case 22: return gARHandle!.pointee.markerInfo.22.id;
        case 23: return gARHandle!.pointee.markerInfo.23.id;
        case 24: return gARHandle!.pointee.markerInfo.24.id;
        case 25: return gARHandle!.pointee.markerInfo.25.id;
        case 26: return gARHandle!.pointee.markerInfo.26.id;
        case 27: return gARHandle!.pointee.markerInfo.27.id;
        case 28: return gARHandle!.pointee.markerInfo.28.id;
        case 29: return gARHandle!.pointee.markerInfo.29.id;

        case 30: return gARHandle!.pointee.markerInfo.30.id;
        case 31: return gARHandle!.pointee.markerInfo.31.id;
        case 32: return gARHandle!.pointee.markerInfo.32.id;
        case 33: return gARHandle!.pointee.markerInfo.33.id;
        case 34: return gARHandle!.pointee.markerInfo.34.id;
        case 35: return gARHandle!.pointee.markerInfo.35.id;
        case 36: return gARHandle!.pointee.markerInfo.36.id;
        case 37: return gARHandle!.pointee.markerInfo.37.id;
        case 38: return gARHandle!.pointee.markerInfo.38.id;
        case 39: return gARHandle!.pointee.markerInfo.39.id;

        case 40: return gARHandle!.pointee.markerInfo.40.id;
        case 41: return gARHandle!.pointee.markerInfo.41.id;
        case 42: return gARHandle!.pointee.markerInfo.42.id;
        case 43: return gARHandle!.pointee.markerInfo.43.id;
        case 44: return gARHandle!.pointee.markerInfo.44.id;
        case 45: return gARHandle!.pointee.markerInfo.45.id;
        case 46: return gARHandle!.pointee.markerInfo.46.id;
        case 47: return gARHandle!.pointee.markerInfo.47.id;
        case 48: return gARHandle!.pointee.markerInfo.48.id;
        case 49: return gARHandle!.pointee.markerInfo.49.id;

        case 50: return gARHandle!.pointee.markerInfo.50.id;
        case 51: return gARHandle!.pointee.markerInfo.51.id;
        case 52: return gARHandle!.pointee.markerInfo.52.id;
        case 53: return gARHandle!.pointee.markerInfo.53.id;
        case 54: return gARHandle!.pointee.markerInfo.54.id;
        case 55: return gARHandle!.pointee.markerInfo.55.id;
        case 56: return gARHandle!.pointee.markerInfo.56.id;
        case 57: return gARHandle!.pointee.markerInfo.57.id;
        case 58: return gARHandle!.pointee.markerInfo.58.id;
        case 59: return gARHandle!.pointee.markerInfo.59.id;
        default: break;
        }

        print("No ID.");
        return 0;
    }

    func getCf(_ num: Int32) -> ARdouble {
        switch num {
        case 0: return gARHandle!.pointee.markerInfo.0.cf;
        case 1: return gARHandle!.pointee.markerInfo.1.cf;
        case 2: return gARHandle!.pointee.markerInfo.2.cf;
        case 3: return gARHandle!.pointee.markerInfo.3.cf;
        case 4: return gARHandle!.pointee.markerInfo.4.cf;
        case 5: return gARHandle!.pointee.markerInfo.5.cf;
        case 6: return gARHandle!.pointee.markerInfo.6.cf;
        case 7: return gARHandle!.pointee.markerInfo.7.cf;
        case 8: return gARHandle!.pointee.markerInfo.8.cf;
        case 9: return gARHandle!.pointee.markerInfo.9.cf;

        case 10: return gARHandle!.pointee.markerInfo.10.cf;
        case 11: return gARHandle!.pointee.markerInfo.11.cf;
        case 12: return gARHandle!.pointee.markerInfo.12.cf;
        case 13: return gARHandle!.pointee.markerInfo.13.cf;
        case 14: return gARHandle!.pointee.markerInfo.14.cf;
        case 15: return gARHandle!.pointee.markerInfo.15.cf;
        case 16: return gARHandle!.pointee.markerInfo.16.cf;
        case 17: return gARHandle!.pointee.markerInfo.17.cf;
        case 18: return gARHandle!.pointee.markerInfo.18.cf;
        case 19: return gARHandle!.pointee.markerInfo.19.cf;

        case 20: return gARHandle!.pointee.markerInfo.20.cf;
        case 21: return gARHandle!.pointee.markerInfo.21.cf;
        case 22: return gARHandle!.pointee.markerInfo.22.cf;
        case 23: return gARHandle!.pointee.markerInfo.23.cf;
        case 24: return gARHandle!.pointee.markerInfo.24.cf;
        case 25: return gARHandle!.pointee.markerInfo.25.cf;
        case 26: return gARHandle!.pointee.markerInfo.26.cf;
        case 27: return gARHandle!.pointee.markerInfo.27.cf;
        case 28: return gARHandle!.pointee.markerInfo.28.cf;
        case 29: return gARHandle!.pointee.markerInfo.29.cf;

        case 30: return gARHandle!.pointee.markerInfo.30.cf;
        case 31: return gARHandle!.pointee.markerInfo.31.cf;
        case 32: return gARHandle!.pointee.markerInfo.32.cf;
        case 33: return gARHandle!.pointee.markerInfo.33.cf;
        case 34: return gARHandle!.pointee.markerInfo.34.cf;
        case 35: return gARHandle!.pointee.markerInfo.35.cf;
        case 36: return gARHandle!.pointee.markerInfo.36.cf;
        case 37: return gARHandle!.pointee.markerInfo.37.cf;
        case 38: return gARHandle!.pointee.markerInfo.38.cf;
        case 39: return gARHandle!.pointee.markerInfo.39.cf;

        case 40: return gARHandle!.pointee.markerInfo.40.cf;
        case 41: return gARHandle!.pointee.markerInfo.41.cf;
        case 42: return gARHandle!.pointee.markerInfo.42.cf;
        case 43: return gARHandle!.pointee.markerInfo.43.cf;
        case 44: return gARHandle!.pointee.markerInfo.44.cf;
        case 45: return gARHandle!.pointee.markerInfo.45.cf;
        case 46: return gARHandle!.pointee.markerInfo.46.cf;
        case 47: return gARHandle!.pointee.markerInfo.47.cf;
        case 48: return gARHandle!.pointee.markerInfo.48.cf;
        case 49: return gARHandle!.pointee.markerInfo.49.cf;

        case 50: return gARHandle!.pointee.markerInfo.50.cf;
        case 51: return gARHandle!.pointee.markerInfo.51.cf;
        case 52: return gARHandle!.pointee.markerInfo.52.cf;
        case 53: return gARHandle!.pointee.markerInfo.53.cf;
        case 54: return gARHandle!.pointee.markerInfo.54.cf;
        case 55: return gARHandle!.pointee.markerInfo.55.cf;
        case 56: return gARHandle!.pointee.markerInfo.56.cf;
        case 57: return gARHandle!.pointee.markerInfo.57.cf;
        case 58: return gARHandle!.pointee.markerInfo.58.cf;
        case 59: return gARHandle!.pointee.markerInfo.59.cf;
        default: break;
        }

        print("No CF.");
        return 0;
    }

}




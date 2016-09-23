//
//  AppDelegate.swift
//  ARToolKitBySwift
//
//  Created by 藤澤研究室 on 2016/07/11.
//  Copyright © 2016年 藤澤研究室. All rights reserved.
//

import UIKit

@UIApplicationMain
class ARAppDelegate: UIResponder, UIApplicationDelegate {
    @IBOutlet internal var window: UIWindow!
    @IBOutlet internal var viewController: ViewController!
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        self.window.rootViewController = self.viewController
        window!.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        viewController.paused = true
        
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        viewController.paused = false
        
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    deinit {
        viewController = nil
        window = nil
        //TODO 親のメモリ開放
    }
    
    
}


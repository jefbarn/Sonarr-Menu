//
//  SonarrApp.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Cocoa

class SonarrApp {

    static let bundleId = "com.osx.sonarr.tv"
    
    class func start() {

        NSWorkspace.sharedWorkspace().launchAppWithBundleIdentifier(bundleId, options: .Async, additionalEventParamDescriptor: nil, launchIdentifier: nil)
        
        if let pid = findSonarrProcessIdentifier() {
            NSLog("SonarrApp->start (\(pid))")
        } else {
            NSLog("SonarrApp->start (???)")
        }
    }
    
    
    class func stop() {

        if let pid = findSonarrProcessIdentifier() {
            NSLog("SonarrApp->stop (\(pid))")
            kill(pid, SIGTERM)
        }
    }
   
    
    class func isRunning(shouldLog shouldLog: Bool = false) -> Bool {

        if let pid = findSonarrProcessIdentifier() {
            if shouldLog {
                NSLog("Sonarr PID found (\(pid))")
            }
            return true
        } else  {
            return false
        }
    }
    
    
    class func executablePath() -> String {
        
        guard let path = NSWorkspace.sharedWorkspace().absolutePathForAppBundleWithIdentifier(bundleId) else {
            NSLog("Error, could not find Sonarr bundle path. Exiting.")
            abort()
        }
        
        guard let execPath = NSBundle(path: path)?.executablePath else {
            NSLog("Error, could not find Sonarr bundle exectable. Exiting.")
            abort()
        }
        
        return execPath
    }
    
    
    static func findSonarrProcessIdentifier() -> pid_t? {
        
        // Try the easy way first
        let apps = NSRunningApplication.runningApplicationsWithBundleIdentifier(bundleId)
        if apps.count > 0 {
            return apps[0].processIdentifier
        }
        
        // App switch do a different context, so we need to check with BSD process list
        for var proc in try! getBSDProcessList() {
            let pid = proc.kp_proc.p_pid
            
            let name = withUnsafePointer(&proc.kp_proc.p_comm, { (ptr) -> String? in
                let int8Ptr = unsafeBitCast(ptr, UnsafePointer<Int8>.self)
                return String.fromCString(int8Ptr)
            }) ?? ""
            
            if name.containsString("mono") {
                // On the right track, get the full path
                let args = getProcessArgs(pid)
                //print(args)
                if args.containsString("NzbDrone") {
                    return pid
                }
            }
        }
        
        return nil
    }
}
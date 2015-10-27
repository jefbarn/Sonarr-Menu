//
//  SonarrApp.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Cocoa

class SonarrApp {

    static let sonarrBundleId = "com.osx.sonarr.tv"
    
    class func start() -> Bool {
        
        let workspace = NSWorkspace.sharedWorkspace()
        
        guard let sonarrPath = workspace.absolutePathForAppBundleWithIdentifier(sonarrBundleId) else {
            showAlert("Could not find Sonarr.app", descripton: "Do you have it installed?")
            return false
        }
        NSLog("Launching Sonarr: \(sonarrPath)")
        

        let launched = workspace.launchAppWithBundleIdentifier(sonarrBundleId, options: .Async,
            additionalEventParamDescriptor: nil, launchIdentifier: nil)
        guard launched else {
            showAlert("Could not launch Sonarr.app")
            return false
        }
        
        if let pid = findSonarrProcessIdentifiers().first {
            NSLog("SonarrApp->start (\(pid))")
        } else {
            NSLog("SonarrApp->start (???)")
        }
        
        return true
    }
    
    class func stop() {

        for pid in findSonarrProcessIdentifiers() {
            NSLog("SonarrApp->stop (\(pid))")
            kill(pid, SIGTERM)
        }
    }
   
    class func isRunning(shouldLog shouldLog: Bool = false) -> Bool {

        let pids = findSonarrProcessIdentifiers()
        if pids.count > 0 {
            if shouldLog {
                for pid in pids {
                    NSLog("Sonarr PID found (\(pid))")
                }
            }
            return true
        } else  {
            return false
        }
    }
    
    static func findSonarrProcessIdentifiers() -> [pid_t] {
        
        // Try the easy way first
        let apps = NSRunningApplication.runningApplicationsWithBundleIdentifier(sonarrBundleId)
        if apps.count > 0 {
            return apps.map{$0.processIdentifier}
        }
        
        // If the Sonarr process restarts, then it's not connected to the window manager,
        // so we need to do a system call to find the process.
        let uid = String(getuid())
        let output = Shell.command("pgrep -U\(uid) -d: -f NzbDrone").output
        
        let pidStr = output.componentsSeparatedByString(":")
        let pids = pidStr.map{pid_t($0)}.flatMap{$0} // Map array of strings to pid_t

        return pids
    }
}
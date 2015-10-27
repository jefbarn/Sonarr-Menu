//
//  LaunchAgent.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Cocoa

class LaunchAgent {
    
    let fm = NSFileManager.defaultManager()
    
    var launchAgentDirectory: NSURL
    var launchAgentFile: NSURL
    
    init() {
        do {
            let libDir = try fm.URLForDirectory(.LibraryDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
            launchAgentDirectory = libDir.URLByAppendingPathComponent("LaunchAgents")
        } catch let error as NSError {
            showAlert("Error, could not locate user Library directory. Exiting.", error: error)
            abort()
        }
        
        launchAgentFile = launchAgentDirectory.URLByAppendingPathComponent("tv.sonarr.Sonarr-Menu.plist")
    }
    
    func add() -> Bool {
        
        // Create LaunchAgent directory if it doesn't exist.
        do {
            if try launchAgentDirectory.checkResourceIsReachable() == false {
                try fm.createDirectoryAtURL(launchAgentDirectory, withIntermediateDirectories: false, attributes: nil)
            }
        } catch let error as NSError {
            showAlert("Error accessing LaunchAgent directory", error: error)
            return false
        }
        
        guard let execPath = NSBundle.mainBundle().executablePath else {
            showAlert("Could not look up executable path.")
            return false
        }
        
        // Create plist with correct executeable
        let plistDict: NSDictionary = [
            "Label": "tv.sonarr.Sonarr-Menu",
            "Program": execPath,
            "RunAtLoad": true
        ]
        
        plistDict.writeToURL(launchAgentFile, atomically: true)
        
        return true
    }
    
    func remove() {
        
        _ = try? fm.removeItemAtURL(launchAgentFile)
    }
    
    func active() -> Bool {
        let reachable = try? launchAgentFile.checkResourceIsReachable()
        return reachable ?? false
    }
    

}
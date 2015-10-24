//
//  LaunchAgent.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Cocoa

class LaunchAgent {
    
    private static let fm = NSFileManager.defaultManager()
    
    
    class func add() {
        // Create plist with correct executeable
        let plistDict = NSMutableDictionary()
        
        plistDict.setObject("com.osx.sonarr.tv.job", forKey: "Label")
        plistDict.setObject(SonarrApp.executablePath(), forKey: "Program")
        plistDict.setObject(true, forKey: "RunAtLoad")
        
        plistDict.writeToURL(launchAgentURL(), atomically: true)
    }
    
    
    class func remove() {
        
        _ = try? fm.removeItemAtURL(launchAgentURL())
    }
    
    
    class func active() -> Bool {
        
        return fm.fileExistsAtPath(launchAgentURL().path!)
    }
    
    
    private class func launchAgentURL() -> NSURL {
        
        let libDir = try! fm.URLForDirectory(.LibraryDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        let agentURL = libDir.URLByAppendingPathComponent("LaunchAgents/SonarrAgent.plist")
        
        return agentURL
    }
}
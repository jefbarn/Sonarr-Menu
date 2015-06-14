//
//  LoginItems.swift
//  Sonarr
//
//  Created by Jeff Barnes on 1/4/15.
//  Copyright (c) 2015 Sonarr. All rights reserved.
//

import Foundation

class LoginItems {
    
    class func addThisApp() {
        
        let bundleName = "Sonarr"
        
        let script =    "set app_path to path to me\n" +
                        "tell application \"System Events\"\n" +
                        "   if \"\(bundleName)\" is not in (name of every login item) then\n" +
                        "       make login item at end with properties {hidden:false, path:app_path}\n" +
                        "   end if\n" +
                        "end tell"
        
        var errorInfo: NSDictionary?
        
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo).stringValue {
            return
        }
        
        if errorInfo != nil {
            NSLog("Error running applescript (addThisApp). ")
            if let errorStr = errorInfo?.valueForKey(NSAppleScriptErrorMessage) as? String {
                NSLog(errorStr)
            }
        }
    }

    class func removeThisApp() {
        
        let bundleName = "Sonarr"
        
        let script =    "tell application \"System Events\"\n" +
                        "   get the name of every login item\n" +
                        "   if login item \"\(bundleName)\" exists then\n" +
                        "       delete login item \"\(bundleName)\"\n" +
                        "   end if\n" +
                        "end tell"
        
        var errorInfo: NSDictionary?
        
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo).stringValue {
            return
        }
        
        if errorInfo != nil {
            NSLog("Error running applescript (removeThisApp). ")
            if let errorStr = errorInfo?.valueForKey(NSAppleScriptErrorMessage) as? String {
                NSLog(errorStr)
            }
        }
    }

    class func containsThisApp() -> Bool {
        
        let bundleName = "Sonarr"
        
        var script =    "tell application \"System Events\"\n"
            script +=   "   get the name of every login item\n"
            script +=   "   if login item \"\(bundleName)\" exists then\n"
            script +=   "       return true\n"
            script +=   "   end if\n"
            script +=   "end tell\n"
            script +=   "return false"
        
        var errorInfo: NSDictionary?
        
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo).stringValue {
            //NSLog("containsThisApp result: \(result)")
            return (result as NSString).boolValue
        }
        
        if errorInfo != nil {
            NSLog("Error running applescript (containsThisApp). ")
            if let errorStr = errorInfo?.valueForKey(NSAppleScriptErrorMessage) as? String {
                NSLog(errorStr)
            }
        }
        
        return false
    }
}
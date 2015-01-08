//
//  DaemonController.swift
//  Sonarr
//
//  Created by Jeff Barnes on 1/6/15.
//  Copyright (c) 2015 Sonarr. All rights reserved.
//

import Foundation

class DaemonController {
    
    var daemonTask = NSTask()
    
    
    func readLockFilePid() -> pid_t? {
        
        let lockFilePath = applicationSupportDirectory().stringByAppendingPathComponent("nzbdrone.pid")
        
        if NSFileManager.defaultManager().fileExistsAtPath(lockFilePath) {
            // Lock file exists
            // read pid from lock file
            if let pid = NSString(contentsOfFile: lockFilePath, encoding: NSUTF8StringEncoding, error: nil)?.integerValue {
                //NSLog("pid: %i", pid)
                
                var command = shellCmd("/bin/ps", "-p", String(pid), "-o", "command=")
                
                //NSLog("command: \(command)")

                if command.rangeOfString(".app/Contents/Resources/bin/NzbDrone.exe") != nil {
                    return pid_t(pid)
                }
            }
        }
        
        return nil
    }


    func killDaemonWithSignal(signal: Int32) {
        
        let lockFilePath = applicationSupportDirectory().stringByAppendingPathComponent("nzbdrone.pid")
        
        if let pid = readLockFilePid() {
            kill(pid, signal)
            NSFileManager.defaultManager().removeItemAtPath(lockFilePath, error: nil)
        }
    }
    
    
    func isRunning() -> Bool {
        if daemonTask.running {
            return true
        }
        if readLockFilePid() != nil {
            return true
        } else {
            return false
        }
    }
    

    func start() {
        
        let binDir = NSBundle.mainBundle().resourcePath!.stringByAppendingPathComponent("bin")
        let monoPath = "/usr/bin/mono"
        
        let exePath = binDir.stringByAppendingPathComponent("NzbDrone.exe")
        
        if !NSFileManager.defaultManager().fileExistsAtPath(exePath) {
            
            let downloader = DownloadSonarr()
            downloader.startDownload(getBranch()) {
                if NSFileManager.defaultManager().fileExistsAtPath(exePath) {
                    self.start()
                } else {
                    NSLog("Error downloading Sonarr files.")
                }
            }
            
        } else {
            
            
            if NSFileManager.defaultManager().fileExistsAtPath(monoPath) == false {
                NSLog("Mono not installed!")
                return
            }
            if NSFileManager.defaultManager().fileExistsAtPath(exePath) == false {
                NSLog("Sonarr daemon not installed!")
                return
            }
            
            if isRunning() {
                NSLog("Sonarr daemon is already running. (pid=\(readLockFilePid()))")
                return
            }
            
            daemonTask = NSTask()
            
            daemonTask.launchPath = monoPath
            daemonTask.arguments = [exePath]
            
            daemonTask.launch()
        }
    }


    func stop() {
        NSLog("DaemonController->stop");
        killDaemonWithSignal(SIGTERM)
    }


    func readConfig() -> [String: NSString] {
        
        let configFilePath = applicationSupportDirectory().stringByAppendingPathComponent("config.xml")
        var config = [String: NSString]()
        
        let xmlDoc = NSXMLDocument(contentsOfURL: NSURL(fileURLWithPath: configFilePath)!, options: Int(NSXMLDocumentTidyHTML), error: nil)
            
        if let nodes = xmlDoc?.nodesForXPath("Config/*", error: nil)? as? [NSXMLNode] {
            for node in nodes {
                config[node.name!] = node.stringValue!
            }
        }
        
        return config
    }


    func getBrowserUrl() -> NSURL {
        
        let config = readConfig()
        
        let port = config["Port"]?.integerValue ?? 8989
            
        return NSURL(string: "http://localhost:\(port)/")!
    }
    
    
    func getBranch() -> String {
        
        let config = readConfig()
        
        return config["Branch"] ?? "master"
    }

}

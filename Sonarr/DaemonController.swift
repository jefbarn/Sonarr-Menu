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
    
    let configFile = appSupportDir().stringByAppendingPathComponent("config.xml")
    var configDict = [String: NSString]()
    
    let lockFile = appSupportDir().stringByAppendingPathComponent("nzbdrone.pid")
    
    var dispatchSource: dispatch_source_t?
    
    init() {
        readConfig()
        // Set up monitoring of config file.
        // If the config file has not been created yet, then monitor the Support directory until it becomes available.
        if NSFileManager.defaultManager().fileExistsAtPath(configFile) {
            dispatchSource = monitorChangesToFile(configFile, readConfig)
        } else {
            dispatchSource = monitorChangesToFile(appSupportDir()) {
                if NSFileManager.defaultManager().fileExistsAtPath(self.configFile) {
                    if self.dispatchSource != nil { dispatch_source_cancel(self.dispatchSource!) }
                    self.dispatchSource = monitorChangesToFile(self.configFile, self.readConfig)
                }
            }
        }
    }
    
    
    func readLockFilePid() -> pid_t? {
        
        if NSFileManager.defaultManager().fileExistsAtPath(lockFile) {
            // Lock file exists
            // read pid from lock file
            if let pid = NSString(contentsOfFile: lockFile, encoding: NSUTF8StringEncoding, error: nil)?.integerValue {
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
        
        if let pid = readLockFilePid() {
            kill(pid, signal)
            NSFileManager.defaultManager().removeItemAtPath(lockFile, error: nil)
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
            downloader.startDownload(branch) {
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


    func readConfig() {
        
        configDict = [:]
        
        let xmlDoc = NSXMLDocument(contentsOfURL: NSURL(fileURLWithPath: configFile)!, options: Int(NSXMLDocumentTidyXML), error: nil)
            
        if let nodes = xmlDoc?.nodesForXPath("Config/*", error: nil) as? [NSXMLNode] {
            for node in nodes {
                configDict[node.name!] = node.stringValue!
            }
        }
    }


    var webInterfaceUrl: NSURL {
        
        let port = configDict["Port"]?.integerValue ?? 8989
        
        return NSURL(string: "http://localhost:\(port)/")!
    }

    
    var branch: String {
        
        return (configDict["Branch"] as? String) ?? "master"
    }

}

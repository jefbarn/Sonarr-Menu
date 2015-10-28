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
    
    let configFile = appSupportDir().URLByAppendingPathComponent("config.xml")
    var configDict = [String: NSString]()
    
    let lockFile = appSupportDir().URLByAppendingPathComponent("nzbdrone.pid")
    
    var dispatchSource: dispatch_source_t?
    
    init() {
        readConfig()
        // Set up monitoring of config file.
        // If the config file has not been created yet, then monitor the Support directory until it becomes available.
        if configFile.checkResourceIsReachable() {
            dispatchSource = monitorChangesToFile(configFile, handler: readConfig)
        } else {
            dispatchSource = monitorChangesToFile(appSupportDir()) {
                if self.configFile.checkResourceIsReachable() {
                    if self.dispatchSource != nil { dispatch_source_cancel(self.dispatchSource!) }
                    self.dispatchSource = monitorChangesToFile(self.configFile, handler: self.readConfig)
                }
            }
        }
    }
    
    
    func readLockFilePid() -> pid_t? {
        
        // Check lock file exists
        guard lockFile.checkResourceIsReachable() else {
            return nil
        }
        
        // read pid from lock file
        do {
            let pid = try NSString(contentsOfURL: lockFile, encoding: NSUTF8StringEncoding).integerValue
            //NSLog("pid: %i", pid)
            
            let command = shellCmd("/bin/ps", args: "-p", String(pid), "-o", "command=")
            
            //NSLog("command: \(command)")

            if command.rangeOfString(".app/Contents/Resources/bin/NzbDrone.exe") != nil {
                return pid_t(pid)
            }
        } catch let error as NSError {
            NSLog("Error reading lock file contents: ", error.localizedDescription)
        }
        
        return nil
    }


    func killDaemonWithSignal(signal: Int32) {
        
        guard let pid = readLockFilePid() else {
            return
        }
        
        kill(pid, signal)
        do {
            try NSFileManager.defaultManager().removeItemAtURL(lockFile)
        } catch let error as NSError {
            NSLog("Error remvoing lock file: ", error.localizedDescription)
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
        
        let binDir = NSBundle.mainBundle().resourceURL!.URLByAppendingPathComponent("bin")
        
        let exePath = binDir.URLByAppendingPathComponent("NzbDrone.exe")
        print("monoPath = \(monoPath.path!)")
        print("exePath = \(exePath.path!)")
        
        if exePath.checkResourceIsReachable() == false {
            
            let downloader = DownloadSonarr()
            downloader.startDownload(branch) {
                if exePath.checkResourceIsReachable() {
                    self.start()
                } else {
                    NSLog("Error downloading Sonarr files.")
                }
            }
            
        } else {
            
            
            if monoPath.checkResourceIsReachable() == false {
                NSLog("Mono not installed!")
                exit(1)
            }
            if exePath.checkResourceIsReachable() == false {
                NSLog("Sonarr daemon not installed!")
                exit(1)
            }
            
            if isRunning() {
                NSLog("Sonarr daemon is already running. (pid=\(readLockFilePid()))")
                exit(1)
            }
            
            daemonTask = NSTask.launchedTaskWithLaunchPath(monoPath.path!, arguments: [exePath.path!])
        }
    }


    func stop() {
        NSLog("DaemonController->stop");
        killDaemonWithSignal(SIGTERM)
    }


    func readConfig() {
        
        configDict = [:]
        
        do {
            let xmlDoc = try NSXMLDocument(contentsOfURL: configFile, options: Int(NSXMLDocumentTidyXML))

            let nodes = try xmlDoc.nodesForXPath("Config/*")
            for node in nodes {
                configDict[node.name!] = node.stringValue!
            }
        } catch let error as NSError {
            NSLog("Error reading config file: ", error.description)
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

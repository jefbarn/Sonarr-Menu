//
//  SonarrConfig.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Foundation

class SonarrConfig {
    
    let fm = NSFileManager.defaultManager()
    
    var configDict = [String: NSString]()
    
    var dispatchSource: dispatch_source_t?
    
    var configDirectory: String
    var configXmlFile: String
    
    init() {
        
        configDirectory = NSString(string: "~/.config/NzbDrone/").stringByExpandingTildeInPath
        configXmlFile = NSString(string: configDirectory).stringByAppendingPathComponent("config.xml")
        
        readConfig()
        
        // Set up monitoring of config file.
        // If the config file has not been created yet, then monitor the Support directory until it becomes available.
        
        if fm.fileExistsAtPath(configXmlFile) {
            dispatchSource = monitorChangesToFile(configXmlFile, handler: readConfig)
        } else {
            if fm.fileExistsAtPath(configDirectory) == false {
                _ = try? self.fm.createDirectoryAtPath(configDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            dispatchSource = monitorChangesToFile(configDirectory) {
                
                if self.fm.fileExistsAtPath(self.configXmlFile) {
                    if self.dispatchSource != nil { dispatch_source_cancel(self.dispatchSource!) }
                    self.readConfig()
                    self.dispatchSource = self.monitorChangesToFile(self.configXmlFile, handler: self.readConfig)
                }
            }
        }
    }
    
    func monitorChangesToFile(filename: String, handler: ()->()) -> dispatch_source_t? {
        
        NSLog("Monitoring \(filename) for changes.")
        
        var buffer = Array<Int8>(count: Int(PATH_MAX), repeatedValue: 0)
        NSURL(fileURLWithPath: filename).getFileSystemRepresentation(&buffer, maxLength: Int(PATH_MAX))
        
        let fileDescriptor = open(&buffer, O_EVTONLY)
        if (fileDescriptor >= 0) {
            
            let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            
            if let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, UInt(fileDescriptor), DISPATCH_VNODE_WRITE, queue) {
                
                dispatch_source_set_event_handler(source) {
                    handler()
                }
                
                dispatch_source_set_cancel_handler(source) {
                    close(fileDescriptor)
                    return
                }
                
                dispatch_resume(source)
                return source
            } else {
                NSLog("Error: could not create file event dispatch source.")
                close(fileDescriptor)
            }
            
        } else {
            NSLog("Error: could not open \(filename) for reading.")
        }
        return nil
    }
    
    func readConfig() {

        configDict = [:]
        
        do {
            let xmlDoc = try NSXMLDocument(contentsOfURL: NSURL(fileURLWithPath: configXmlFile), options: Int(NSXMLDocumentTidyXML))
            
            let nodes = try xmlDoc.nodesForXPath("Config/*")
            for node in nodes {
                configDict[node.name!] = node.stringValue!
            }
        } catch let error as NSError {
            NSLog("Error reading config file: \(error.description)")
        }
    }
    
    func webInterfaceURL() -> NSURL {
        
        let port = configDict["Port"]?.integerValue ?? 8989
        let urlBase = configDict["UrlBase"] ?? ""
        
        return NSURL(string: "http://localhost:\(port)/\(urlBase)")!
    }
    
    func shouldLaunchBrowser() -> Bool {
        return configDict["LaunchBrowser"]?.boolValue ?? false
    }
}
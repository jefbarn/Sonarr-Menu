//
//  Tools.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/25/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Cocoa

class Shell {

    // Grep exit status
    struct Grep {
        static let Found = 0
        static let NotFound = 1
    }

    static func command(command: String) -> (output: String, exitStatus: Int) {
        
        let task = NSTask()
        let stdout = NSPipe()
        
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = stdout
        
        task.launch()
        task.waitUntilExit()
        
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let outStr = NSString(data: outData, encoding: NSUTF8StringEncoding) ?? ""
        return (outStr as String, Int(task.terminationStatus))
    }
}

func showAlert(errorText: String, descripton: String? = nil, error: NSError? = nil) {
    
    NSLog("%@, %@, %@", errorText, descripton ?? "nil", error?.description ?? "nil")
    
    let alert = NSAlert()
    alert.messageText = "Sonarr Menu:\n" + errorText
    alert.informativeText = descripton ?? (error?.localizedDescription ?? "")
    alert.alertStyle = .CriticalAlertStyle
    alert.runModal()
}

// Shim checkResourceIsReachableAndReturnError to use the Swift 2.0 throws convention
// (Apple will probably fix this soon)
extension NSURL {
    func checkResourceIsReachable() throws -> Bool {
        var error: NSError?
        let reachable = self.checkResourceIsReachableAndReturnError(&error)
        if let error = error {
            throw error
        }
        return reachable
    }
}
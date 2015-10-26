//
//  Shell.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/25/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Foundation

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
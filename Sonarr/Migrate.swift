//
//  Migrate.swift
//  Sonarr
//
//  Created by Jeff Barnes on 1/4/15.
//  Copyright (c) 2015 Sonarr. All rights reserved.
//

import Foundation

class Migrate {
    
    let fileManager = NSFileManager.defaultManager()

    
    init() {
        
        migrateAppSupportDir()
    }
    
    func migrateAppSupportDir() {
        //  Possible application support directories: (in order of appearance)
        //      ~/.config/NzbDrone (dir or symlink)
        //      /Library/Application Support/NzbDrone
        //      /Users/Current User/Library/Application Support/NzbDrone
        //
        //  New Target:
        //      /Users/Current User/Library/Application Support/Sonarr
        //      ~/.config/NzbDrone -> symlink to new target
        
        var movedFiles = false
        
        
        let localDomainDir = fileManager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .LocalDomainMask, appropriateForURL: nil, create: false, error: nil)?.path
        let userDomainDir  = fileManager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false, error: nil)?.path
        
        if let targetDir = userDomainDir?.stringByAppendingPathComponent("Sonarr") {
            
            if fileManager.fileExistsAtPath(targetDir) {
                NSLog("App support directory \(targetDir) exists.")
                // If the target directory is already in use, don't copy files over ones already there.
                movedFiles = true
            }
                
            let dir = "~/.config/NzbDrone".stringByExpandingTildeInPath
            
            if fileManager.fileExistsAtPath(dir) {
                if !isSymbolicLink(dir) {
                    if !movedFiles {
                        moveFiles(dir, dest: targetDir)
                        movedFiles = true
                    } else {
                        deleteFiles(dir)
                    }
                }
            }
            
            if let dir = localDomainDir?.stringByAppendingPathComponent("NzbDrone") {
                
                if fileManager.fileExistsAtPath(dir) {
                    if !movedFiles {
                        moveFiles(dir, dest: targetDir)
                        movedFiles = true
                    } else {
                        deleteFiles(dir)
                    }
                }
            }
            
            if let dir = userDomainDir?.stringByAppendingPathComponent("NzbDrone") {
                
                if fileManager.fileExistsAtPath(dir) {
                    if !movedFiles {
                        moveFiles(dir, dest: targetDir)
                        movedFiles = true
                    } else {
                        deleteFiles(dir)
                    }
                }
            }
            
            // Create a new support directory if we didn't find any old files
            if !movedFiles {
                createDirectory(targetDir)
            }

            
            // Update symlink
            let linkPath = "~/.config/NzbDrone".stringByExpandingTildeInPath
            
            if fileManager.fileExistsAtPath(linkPath) {
                if !isSymbolicLinkTo(linkPath, dest: targetDir) {  // check for symlink to wrong destination
                    deleteFiles(linkPath)
                    createSymlink(linkPath, dest: targetDir)
                }
            } else {
                createSymlink(linkPath, dest: targetDir)
            }
            
            // Remove old bin directory if it exists
            let binDir = targetDir.stringByAppendingPathComponent("bin")
            if fileManager.fileExistsAtPath(binDir) {
                deleteFiles(binDir)
            }

            
        } else {
            
            NSLog("Unable to find or create application support directory (migrate).")
            
            return
        }
        
    }
    
    
    func moveFiles(path: String, dest: String) -> Bool {
        var error: NSError?
        NSLog("Moving files from \(path) to \(dest)")
        let result = fileManager.moveItemAtPath(path, toPath: dest, error: &error)
        if (error != nil) { NSLog("Error: " + error!.localizedDescription) }
        return result
    }
    
    
    func deleteFiles(path: String) {
        var error: NSError?
        NSLog("Deleting files from \(path)")
        fileManager.removeItemAtPath(path, error: &error)
        if (error != nil) { NSLog("Error: " + error!.localizedDescription) }
    }
    
    
    func createDirectory(path: String) {
        var error: NSError?
        NSLog("Creating directory at \(path)")
        fileManager.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil, error: &error)
        if (error != nil) { NSLog("Error: " + error!.localizedDescription) }
    }
    
    
    func createSymlink(path: String, dest: String) {
        var error: NSError?
        NSLog("Creating symlink from \(path) to \(dest)")
        fileManager.createSymbolicLinkAtPath(path, withDestinationPath: dest, error: &error)
        if (error != nil) { NSLog("Error: " + error!.localizedDescription) }
    }
    
    
    func isSymbolicLink(path: String) -> Bool {
        var error: NSError?
        //NSLog("Checking if \(path) is a symlink.")
        if let fileType = fileManager.attributesOfItemAtPath(path, error: &error)?[NSFileType]? as? NSString {
            if fileType == NSFileTypeSymbolicLink {
                return true
            }
        }
        if (error != nil) { NSLog("Error: " + error!.localizedDescription) }
        return false
    }
    
    func isSymbolicLinkTo(path: String, dest: String) -> Bool {
        var error: NSError?
        //NSLog("Checking if \(path) is a symlink to \(dest)...")
        if isSymbolicLink(path) {
            if let linkDest = fileManager.destinationOfSymbolicLinkAtPath(path, error: &error) {
                if linkDest == dest {
                    return true
                }
            }
        }
        if (error != nil) { NSLog("Error: " + error!.localizedDescription) }
        return false
    }
    
}
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
        
        var localDomainDir: NSURL?
        var userDomainDir: NSURL?
        do {
            localDomainDir = try fileManager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .LocalDomainMask, appropriateForURL: nil, create: false)
        } catch {  }
        do {
            userDomainDir  = try fileManager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        } catch {  }
        
        if let targetDir = userDomainDir?.URLByAppendingPathComponent("Sonarr") {
            
            if targetDir.checkResourceIsReachable() {
                NSLog("App support directory \(targetDir) exists.")
                // If the target directory is already in use, don't copy files over ones already there.
                movedFiles = true
            }
                
            let dir = NSURL(fileURLWithPath: NSString(string: "~/.config/NzbDrone").stringByExpandingTildeInPath)
            
            if dir.checkResourceIsReachable() {
                if !isSymbolicLink(dir) {
                    if !movedFiles {
                        moveFiles(dir, dest: targetDir)
                        movedFiles = true
                    } else {
                        deleteFiles(dir)
                    }
                }
            }
            
            if let dir = localDomainDir?.URLByAppendingPathComponent("NzbDrone") {
                
                if dir.checkResourceIsReachable() {
                    if !movedFiles {
                        moveFiles(dir, dest: targetDir)
                        movedFiles = true
                    } else {
                        deleteFiles(dir)
                    }
                }
            }
            
            if let dir = userDomainDir?.URLByAppendingPathComponent("NzbDrone") {
                
                if dir.checkResourceIsReachable() {
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
            let linkPath = NSURL(fileURLWithPath: NSString(string: "~/.config/NzbDrone").stringByExpandingTildeInPath)
            
            if linkPath.checkResourceIsReachable() {
                if !isSymbolicLinkTo(linkPath, dest: targetDir) {  // check for symlink to wrong destination
                    deleteFiles(linkPath)
                    createSymlink(linkPath, dest: targetDir)
                }
            } else {
                createSymlink(linkPath, dest: targetDir)
            }
            
            // Remove old bin directory if it exists
            let binDir = targetDir.URLByAppendingPathComponent("bin")
            if binDir.checkResourceIsReachable() {
                deleteFiles(binDir)
            }

            
        } else {
            
            NSLog("Unable to find or create application support directory (migrate).")
            return
        }
        
    }
    
    
    func moveFiles(path: NSURL, dest: NSURL) -> Bool {

        NSLog("Moving files from \(path) to \(dest)")

        do {
            try fileManager.moveItemAtURL(path, toURL: dest)
            return true
        } catch let error as NSError {
            NSLog("Error moving files: " + error.localizedDescription)
            return false
        }
    }
    
    
    func deleteFiles(path: NSURL) {

        NSLog("Deleting files from \(path)")
        do {
            try fileManager.removeItemAtURL(path)
        } catch let error as NSError {
            NSLog("Error deleting files: " + error.localizedDescription)
        }
    }
    
    
    func createDirectory(path: NSURL) {

        NSLog("Creating directory at \(path)")
        do {
            try fileManager.createDirectoryAtURL(path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Error creating directory: " + error.localizedDescription)
        }
    }
    
    
    func createSymlink(path: NSURL, dest: NSURL) {

        NSLog("Creating symlink from \(path) to \(dest)")
        do {
            try fileManager.createSymbolicLinkAtURL(path, withDestinationURL: dest)
        } catch let error as NSError {
            NSLog("Error creating symlink: " + error.localizedDescription)
        }
    }
    
    
    func isSymbolicLink(path: NSURL) -> Bool {

        //NSLog("Checking if \(path) is a symlink.")
        do {
            let fileType = try fileManager.attributesOfItemAtPath(path.path!)[NSFileType] as? String
            if fileType == NSFileTypeSymbolicLink {
                return true
            }
        
        } catch let error as NSError {
            NSLog("Error checking symlink: " + error.localizedDescription)
        }
        return false
    }
    
    func isSymbolicLinkTo(path: NSURL, dest: NSURL) -> Bool {

        //NSLog("Checking if \(path) is a symlink to \(dest)...")
        if isSymbolicLink(path) {
            do {
                let linkDest = try fileManager.destinationOfSymbolicLinkAtPath(path.path!)
                if linkDest == dest {
                    return true
                }
            } catch let error as NSError {
                NSLog("Error checking symlink to: " + error.localizedDescription)
            }
        }

        return false
    }
    
}
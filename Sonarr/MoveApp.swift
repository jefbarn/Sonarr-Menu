//
//  MoveApp.swift
//  Sonarr
//
//  Created by Jeff Barnes on 1/4/15.
//  Copyright (c) 2015 Sonarr. All rights reserved.
//
//  Heavily modified from https://github.com/potionfactory/LetsMove (public domain)

import Cocoa



// By default, we use a small control/font for the suppression button.
// If you prefer to use the system default (to match your other alerts),
// set this to 0.
let UseSmallAlertSuppressCheckbox = true


let AlertSuppressKey = "moveToApplicationsFolderAlertSuppress"


// Main worker function
func moveToApplicationsFolder() {
    // Skip if user suppressed the alert before
    if NSUserDefaults.standardUserDefaults().boolForKey(AlertSuppressKey) {
        return
    }
    
    // Path of the bundle
    let bundlePath = NSBundle.mainBundle().bundlePath
    
    // Skip if the application is already in some Applications folder
    if (isInApplicationsFolder(bundlePath)) { return }
    
    // File Manager
    let fm = NSFileManager.defaultManager()
    
    
    // Since we are good to go, get the preferred installation directory.
    let (applicationsDirectory, installToUserApplications) = preferredInstallLocation()
    let bundleName = bundlePath.lastPathComponent
    let destinationPath = applicationsDirectory.stringByAppendingPathComponent(bundleName)
    
    // Check if we need admin password to write to the Applications directory
    // Check if the destination bundle is already there but not writable
    let needAuthorization = !fm.isWritableFileAtPath(applicationsDirectory) || (fm.fileExistsAtPath(destinationPath) && !fm.isWritableFileAtPath(destinationPath))
    
    // Setup the alert
    let alert = NSAlert()
    
    alert.messageText = installToUserApplications ? "Move to Applications folder in your Home folder?" : "Move to Applications folder?"
    
    var informativeText = "I can move myself to the Applications folder if you'd like."
    
    if needAuthorization {
        informativeText += " " + "Note that this will require an administrator password."
    
    } else if isInDownloadsFolder(bundlePath) {
        // Don't mention this stuff if we need authentication. The informative text is long enough as it is in that case.
        informativeText += " " + "This will keep your Downloads folder uncluttered."
    }
    
    alert.informativeText = informativeText
    
    // Add accept button
    alert.addButtonWithTitle("Move to Applications Folder")
    
    // Add deny button
    let cancelButton = alert.addButtonWithTitle("Do Not Move")
    cancelButton.keyEquivalent = "\u{1B}"
    
    // Setup suppression button
    alert.showsSuppressionButton = true
    
    if UseSmallAlertSuppressCheckbox {
        if let cell = alert.suppressionButton?.cell() as? NSCell {
            cell.controlSize = .SmallControlSize
            cell.font = NSFont.systemFontOfSize(NSFont.smallSystemFontSize())
        }
    }
    
    
    // Activate app -- work-around for focus issues related to "scary file from internet" OS dialog.
    if !NSApp.isActive {
        NSApp.activateIgnoringOtherApps(true)
    }
    
    if alert.runModal() == NSAlertFirstButtonReturn {
        NSLog("INFO -- Moving myself to the Applications folder")
        
        // Move
        if needAuthorization {
            
            if !authorizedInstall(bundlePath, destinationPath) {
                
                NSLog("ERROR -- Could not copy myself to /Applications with authorization")
                //failureAlert()
                return
            }
        } else {
            // If a copy already exists in the Applications folder, put it in the Trash
            if fm.fileExistsAtPath(destinationPath) {
                // But first, make sure that it's not running
                if isApplicationAtPathRunning(destinationPath) {
                    // Give the running app focus and terminate myself
                    NSLog("INFO -- Switching to an already running version")
                    NSTask.launchedTaskWithLaunchPath("/usr/bin/open", arguments: [destinationPath]).waitUntilExit()
                    exit(0)
                } else {
                    if !trash(applicationsDirectory.stringByAppendingPathComponent(bundleName)) {
                        //failureAlert()
                        return
                    }
                }
            }
            
            if !copyBundle(bundlePath, destinationPath) {
                //failureAlert("Could not copy myself to \(destinationPath)")
                return
            }
        }
        
        // Trash the original app. It's okay if this fails.
        // NOTE: This final delete does not work if the source bundle is in a network mounted volume.
        //       Calling rm or file manager's delete method doesn't work either. It's unlikely to happen
        //       but it'd be great if someone could fix this.
        if !deleteOrTrash(bundlePath) {
            NSLog("WARNING -- Could not delete application after moving it to Applications folder")
        }
        
        // Relaunch.
        relaunch(destinationPath)
        
        exit(0)
    } else if alert.suppressionButton!.state == NSOnState {
        // Save the alert suppress preference if checked
        NSUserDefaults.standardUserDefaults().setBool(true, forKey:AlertSuppressKey)
    }
    
    return
}


func preferredInstallLocation() -> (location: String, isUserDirectory: Bool) {
    // Return the preferred install location.
    // Assume that if the user has a ~/Applications folder, they'd prefer their
    // applications to go there.
    let fm = NSFileManager.defaultManager()
    
    if let userApplicationsDir = fm.URLForDirectory(.ApplicationDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false, error: nil) {
        // User Applications directory exists. Get the directory contents.
        if let contents = fm.contentsOfDirectoryAtURL(userApplicationsDir, includingPropertiesForKeys: nil, options: nil, error: nil) as? [NSURL] {
            
            // Check if there is at least one ".app" inside the directory.
            for contentsPath in contents {
                if contentsPath.pathExtension == "app" {
                    return (userApplicationsDir.URLByResolvingSymlinksInPath!.path!, true)
                }
            }
        }
    }
    
    if let localApplicationsDir = fm.URLForDirectory(.ApplicationDirectory, inDomain: .LocalDomainMask, appropriateForURL: nil, create: false, error: nil) {
        if let path = localApplicationsDir.URLByResolvingSymlinksInPath?.path {
            return (path, false)
        }
    }
    
    return ("", false)
}


func isInApplicationsFolder(path: String) -> Bool {
    
    let fm = NSFileManager.defaultManager()
    
    // Check all the normal Application directories
    if let applicationDirs = fm.URLsForDirectory(.ApplicationDirectory, inDomains: .AllDomainsMask) as? [NSURL] {
        for appDir in applicationDirs {
            if path.hasPrefix(appDir.path!) {
                return true
            }
        }
    }
    
    // Also, handle the case that the user has some other Application directory (perhaps on a separate data partition).
    if contains(path.pathComponents, "Applications") {
        return true
    }
    
    return false
}


func isInDownloadsFolder(path: String) -> Bool {
    
    let fm = NSFileManager.defaultManager()
    
    if let downloadDirs = fm.URLsForDirectory(.DownloadsDirectory, inDomains: .UserDomainMask) as? [NSURL] {
        for downloadsDirPath in downloadDirs {
            if path.hasPrefix(downloadsDirPath.path!) {
                return true
            }
        }
    }
    
    return false
}


func isApplicationAtPathRunning(path: String) -> Bool {
    
    // Use the new API on 10.6 or higher to determine if the app is already running
    for runningApplication in NSWorkspace.sharedWorkspace().runningApplications as! [NSRunningApplication] {
        let executablePath = runningApplication.executableURL!.path!
        if executablePath.hasPrefix(path) {
            return true
        }
    }
    return false
}


func trash(path: String) -> Bool {
    if NSWorkspace.sharedWorkspace().performFileOperation(
        NSWorkspaceRecycleOperation,
        source: path.stringByDeletingLastPathComponent, destination: "", files: [path.lastPathComponent], tag: nil) {
        return true
    } else {
        NSLog("ERROR -- Could not trash '%@'", path)
        return false
    }
}


func deleteOrTrash(path: String) -> Bool {
    var error: NSError?
    
    if NSFileManager.defaultManager().removeItemAtPath(path, error: &error) {
        return true
    } else {
        NSLog("WARNING -- Could not delete '%@': %@", path, error!.localizedDescription)
        NSAlert(error: error!).runModal()
        return trash(path)
    }
}

func authorizedInstall(srcPath: String, dstPath: String) -> Bool {
    
    // Make sure that the destination path is an app bundle. We're essentially running 'sudo rm -rf'
    // so we really don't want to mess this up.
    if !dstPath.hasSuffix(".app") { return false }
    
    // Do some more checks
    if dstPath.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) == "" { return false }
    if srcPath.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) == "" { return false }

    // Delete the destination
    if sudoShellCmd("/bin/rm", "-rf", dstPath) == nil {
        return false
    }

    // Copy
    if sudoShellCmd("/bin/cp", "-pR", srcPath, dstPath) == nil {
        return false
    }

    return true
}


func copyBundle(srcPath: String, dstPath: String) -> Bool {
    let fm = NSFileManager.defaultManager()
    var error: NSError?
    
    if fm.copyItemAtPath(srcPath, toPath:dstPath, error: &error) {
        return true
    } else {
        NSLog("ERROR -- Could not copy '%@' to '%@' (%@)", srcPath, dstPath, error!.localizedDescription)
        NSAlert(error: error!).runModal()
        return false
    }
}


func relaunch(destinationPath: String) {
    // The shell script waits until the original app process terminates.
    // This is done so that the relaunched app opens as the front-most app.
    let pid = NSProcessInfo.processInfo().processIdentifier
    
    // Command run just before running open /final/path
    let quotedDestinationPath = shellQuotedString(destinationPath)
    
    // OS X >=10.5:
    // Before we launch the new app, clear xattr:com.apple.quarantine to avoid
    // duplicate "scary file from the internet" dialog.
    // Add the -r flag on 10.6
    let preOpenCmd = String(format: "/usr/bin/xattr -d -r com.apple.quarantine %@", quotedDestinationPath)

    let script = String(format: "(while /bin/kill -0 %d >&/dev/null; do /bin/sleep 0.1; done; %@; /usr/bin/open %@) &", pid, preOpenCmd, quotedDestinationPath)
    
    NSTask.launchedTaskWithLaunchPath("/bin/sh", arguments: ["-c", script])
}


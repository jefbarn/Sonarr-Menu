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
    
    // URL of the bundle
    let bundleURL = NSBundle.mainBundle().bundleURL
    
    // Skip if the application is already in some Applications folder
    if (isInApplicationsFolder(bundleURL)) { return }
    
    // File Manager
    let fm = NSFileManager.defaultManager()
    
    
    // Since we are good to go, get the preferred installation directory.
    let (applicationsDirectory, installToUserApplications) = preferredInstallLocation()
    let bundleName = bundleURL.lastPathComponent!
    let destinationURL = applicationsDirectory.URLByAppendingPathComponent(bundleName)
    
    // Check if we need admin password to write to the Applications directory
    // Check if the destination bundle is already there but not writable
    let needAuthorization = !fm.isWritableFileAtPath(applicationsDirectory.path!) || (fm.fileExistsAtPath(destinationURL.path!) && !fm.isWritableFileAtPath(destinationURL.path!))
    
    // Setup the alert
    let alert = NSAlert()
    
    alert.messageText = installToUserApplications ? "Move to Applications folder in your Home folder?" : "Move to Applications folder?"
    
    var informativeText = "I can move myself to the Applications folder if you'd like."
    
    if needAuthorization {
        informativeText += " " + "Note that this will require an administrator password."
    
    } else if isInDownloadsFolder(bundleURL) {
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
        if let cell = alert.suppressionButton?.cell {
            cell.controlSize = .SmallControlSize
            cell.font = NSFont.systemFontOfSize(NSFont.smallSystemFontSize())
        }
    }
    
    
    // Activate app -- work-around for focus issues related to "scary file from internet" OS dialog.
    if !NSApp.active {
        NSApp.activateIgnoringOtherApps(true)
    }
    
    if alert.runModal() == NSAlertFirstButtonReturn {
        NSLog("INFO -- Moving myself to the Applications folder")
        
        // Move
        if needAuthorization {
            
            if !authorizedInstall(bundleURL, dstURL: destinationURL) {
                
                NSLog("ERROR -- Could not copy myself to /Applications with authorization")
                //failureAlert()
                return
            }
        } else {
            // If a copy already exists in the Applications folder, put it in the Trash
            if destinationURL.checkResourceIsReachable() {
                // But first, make sure that it's not running
                if isApplicationAtURLRunning(destinationURL) {
                    // Give the running app focus and terminate myself
                    NSLog("INFO -- Switching to an already running version")
                    NSTask.launchedTaskWithLaunchPath("/usr/bin/open", arguments: [destinationURL.path!]).waitUntilExit()
                    exit(0)
                } else {
                    if !trash(applicationsDirectory.URLByAppendingPathComponent(bundleName)) {
                        //failureAlert()
                        return
                    }
                }
            }
            
            if !copyBundle(bundleURL, dstURL: destinationURL) {
                //failureAlert("Could not copy myself to \(destinationURL)")
                return
            }
        }
        
        // Trash the original app. It's okay if this fails.
        // NOTE: This final delete does not work if the source bundle is in a network mounted volume.
        //       Calling rm or file manager's delete method doesn't work either. It's unlikely to happen
        //       but it'd be great if someone could fix this.
        if !deleteOrTrash(bundleURL) {
            NSLog("WARNING -- Could not delete application after moving it to Applications folder")
        }
        
        // Relaunch.
        relaunch(destinationURL)
        
        exit(0)
    } else if alert.suppressionButton!.state == NSOnState {
        // Save the alert suppress preference if checked
        NSUserDefaults.standardUserDefaults().setBool(true, forKey:AlertSuppressKey)
    }
    
    return
}


func preferredInstallLocation() -> (location: NSURL, isUserDirectory: Bool) {
    // Return the preferred install location.
    // Assume that if the user has a ~/Applications folder, they'd prefer their
    // applications to go there.
    let fm = NSFileManager.defaultManager()
    
    do {
        let userApplicationsDir = try fm.URLForDirectory(.ApplicationDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        // User Applications directory exists. Get the directory contents.
        let contents = try fm.contentsOfDirectoryAtURL(userApplicationsDir, includingPropertiesForKeys: nil, options: [])
            
        // Check if there is at least one ".app" inside the directory.
        for contentsURL in contents {
            if contentsURL.pathExtension == "app" {
                return (userApplicationsDir.URLByResolvingSymlinksInPath!, true)
            }
        }
    } catch {
    }
    
    do {
        let localApplicationsDir = try fm.URLForDirectory(.ApplicationDirectory, inDomain: .LocalDomainMask, appropriateForURL: nil, create: false)
        if let url = localApplicationsDir.URLByResolvingSymlinksInPath {
            return (url, false)
        }
    } catch _ {
    }
    
    return (NSURL(fileURLWithPath: ""), false)
}


func isInApplicationsFolder(url: NSURL) -> Bool {
    
    let fm = NSFileManager.defaultManager()
    
    // Check all the normal Application directories
    let applicationDirs = fm.URLsForDirectory(.ApplicationDirectory, inDomains: .AllDomainsMask)
    for appDir in applicationDirs {
        if url.path!.hasPrefix(appDir.path!) {
            return true
        }
    }

    
    // Also, handle the case that the user has some other Application directory (perhaps on a separate data partition).
    if url.pathComponents!.contains("Applications") {
        return true
    }
    
    return false
}


func isInDownloadsFolder(url: NSURL) -> Bool {
    
    let fm = NSFileManager.defaultManager()
    
    let downloadDirs = fm.URLsForDirectory(.DownloadsDirectory, inDomains: .UserDomainMask)
    for downloadsDirURL in downloadDirs {
        if url.path!.hasPrefix(downloadsDirURL.path!) {
            return true
        }
    }

    
    return false
}


func isApplicationAtURLRunning(url: NSURL) -> Bool {
    
    // Use the new API on 10.6 or higher to determine if the app is already running
    for runningApplication in NSWorkspace.sharedWorkspace().runningApplications as [NSRunningApplication] {
        let executablePath = runningApplication.executableURL!.path!
        if executablePath.hasPrefix(url.path!) {
            return true
        }
    }
    return false
}


func trash(url: NSURL) -> Bool {
    if NSWorkspace.sharedWorkspace().performFileOperation(
        NSWorkspaceRecycleOperation,
        source: url.URLByDeletingLastPathComponent!.path!, destination: "", files: [url.lastPathComponent!], tag: nil) {
        return true
    } else {
        NSLog("ERROR -- Could not trash '%@'", url)
        return false
    }
}


func deleteOrTrash(url: NSURL) -> Bool {
    
    do {
        try NSFileManager.defaultManager().removeItemAtURL(url)
        return true
    } catch let error as NSError {
        NSLog("WARNING -- Could not delete '%@': %@", url, error.localizedDescription)
        NSAlert(error: error).runModal()
        return trash(url)
    }
}

func authorizedInstall(srcURL: NSURL, dstURL: NSURL) -> Bool {
    
    // Make sure that the destination URL is an app bundle. We're essentially running 'sudo rm -rf'
    // so we really don't want to mess this up.
    if dstURL.pathExtension != "app" { return false }
    
    // Do some more checks
    if dstURL.path!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) == "" { return false }
    if srcURL.path!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) == "" { return false }

    // Delete the destination
    if sudoShellCmd("/bin/rm", args: "-rf", dstURL.path!) == nil {
        return false
    }

    // Copy
    if sudoShellCmd("/bin/cp", args: "-pR", srcURL.path!, dstURL.path!) == nil {
        return false
    }

    return true
}


func copyBundle(srcURL: NSURL, dstURL: NSURL) -> Bool {
    let fm = NSFileManager.defaultManager()
    
    do {
        try fm.copyItemAtURL(srcURL, toURL:dstURL)
        return true
    } catch let error as NSError {
        NSLog("ERROR -- Could not copy '%@' to '%@' (%@)", srcURL, dstURL, error.localizedDescription)
        NSAlert(error: error).runModal()
        return false
    }
}


func relaunch(destinationURL: NSURL) {
    // The shell script waits until the original app process terminates.
    // This is done so that the relaunched app opens as the front-most app.
    let pid = NSProcessInfo.processInfo().processIdentifier
    
    // Command run just before running open /final/path
    let quotedDestinationPath = shellQuotedString(destinationURL.path!)
    
    // OS X >=10.5:
    // Before we launch the new app, clear xattr:com.apple.quarantine to avoid
    // duplicate "scary file from the internet" dialog.
    // Add the -r flag on 10.6
    let preOpenCmd = String(format: "/usr/bin/xattr -d -r com.apple.quarantine %@", quotedDestinationPath)

    let script = String(format: "(while /bin/kill -0 %d >&/dev/null; do /bin/sleep 0.1; done; %@; /usr/bin/open %@) &", pid, preOpenCmd, quotedDestinationPath)
    
    NSTask.launchedTaskWithLaunchPath("/bin/sh", arguments: ["-c", script])
}


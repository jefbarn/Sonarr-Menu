//
//  AppDelegate.swift
//  Sonarr
//
//  Created by Jeff Barnes on 12/29/14.
//  Copyright (c) 2014 Sonarr. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var loginMenuItem: NSMenuItem!
    @IBOutlet weak var statusMenuItem: NSMenuItem!

    var statusItem: NSStatusItem!
    
    var monoDialog: MonoDialog!
    
    let homepageUrl = NSURL(string: "https://sonarr.tv/")!
    
    let monoPath = "/usr/bin/mono"
    let binDir = NSBundle.mainBundle().resourcePath!.stringByAppendingPathComponent("bin")
       
    var daemon = DaemonController()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
               
        moveToApplicationsFolder()
        
        let migrater = Migrate()
        
        if MonoDialog.isMonoUpToDate() {
            createStatusMenu()
        } else {
            monoDialog = MonoDialog(windowNibName: "MonoDialog")
            monoDialog.showDialog(createStatusMenu)
        }
    }
    
    func createStatusMenu() {
        // Create the status bar menu
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
        
        statusItem.image = NSImage(named: "StatusIcon")
        statusItem.image!.setTemplate(true)
        statusItem.highlightMode = true
        
        if LoginItems.containsThisApp() {
            loginMenuItem.state = NSOnState
        } else {
            loginMenuItem.state = NSOffState
        }
        
        statusItem.menu = statusMenu
        
        statusMenu.delegate = self
        
        daemon.start()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        daemon.stop()
    }

    @IBAction func runDaemonAction(sender: AnyObject) {
        daemon.start()
    }

    @IBAction func webInterfaceAction(sender: AnyObject) {
        NSWorkspace.sharedWorkspace().openURL(daemon.getBrowserUrl())
    }
    
    @IBAction func homepageAction(sender: AnyObject) {
        NSWorkspace.sharedWorkspace().openURL(homepageUrl)
    }
    
    @IBAction func aboutAction(sender: AnyObject) {
        NSApplication.sharedApplication().orderFrontStandardAboutPanel(self)
    }
    
    @IBAction func runAtLoginAction(sender: AnyObject) {
        if LoginItems.containsThisApp() {
            LoginItems.removeThisApp();
            loginMenuItem.state = NSOffState
        } else {
            LoginItems.addThisApp();
            loginMenuItem.state = NSOnState
        }
    }
    
    @IBAction func quitAction(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    
    func menuWillOpen(menu: NSMenu!) {

        if daemon.isRunning() {
            statusMenuItem.title = "Running"
            statusMenuItem.enabled = false
        } else {
            statusMenuItem.title = "Start Sonarr"
            statusMenuItem.enabled = true
        }
    }
    
}


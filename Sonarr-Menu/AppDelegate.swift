//
//  AppDelegate.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var loginMenuItem: NSMenuItem!
    @IBOutlet weak var statusMenuItem: NSMenuItem!

    var statusItem: NSStatusItem!
    
    let sonarrConfig = SonarrConfig()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Create the status bar menu
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
        
        statusItem.image = NSImage(named: "StatusIcon")
        statusItem.image!.template = true
        statusItem.highlightMode = true
        
        if LaunchAgent.active() {
            loginMenuItem.state = NSOnState
        } else {
            loginMenuItem.state = NSOffState
        }
        
        statusItem.menu = statusMenu
        
        statusMenu.delegate = self
        
        if !SonarrApp.isRunning(shouldLog: true) {
            SonarrApp.start()
        }
        
        if sonarrConfig.shouldLaunchBrowser() {
            NSWorkspace.sharedWorkspace().openURL(sonarrConfig.webInterfaceURL())
        }
    }
    
    func menuWillOpen(menu: NSMenu) {
        
        if SonarrApp.isRunning() {
            statusMenuItem.title = "Running"
            statusMenuItem.enabled = false
        } else {
            statusMenuItem.title = "Start Sonarr"
            statusMenuItem.enabled = true
        }
    }
    
    @IBAction func startAction(sender: NSMenuItem) {
        SonarrApp.start()
    }
    
    @IBAction func webInterfaceAction(sender: NSMenuItem) {
        NSWorkspace.sharedWorkspace().openURL(sonarrConfig.webInterfaceURL())
    }

    @IBAction func homepageAction(sender: NSMenuItem) {
        let homepageUrl = NSURL(string: "https://sonarr.tv/")!
        NSWorkspace.sharedWorkspace().openURL(homepageUrl)
    }

    @IBAction func runAtLoginAction(sender: NSMenuItem) {
        if sender.state == NSOffState {
            LaunchAgent.add()
            sender.state = NSOnState
        } else {
            LaunchAgent.remove()
            sender.state = NSOffState
        }
    }
    
    @IBAction func quitAction(sender: NSMenuItem) {
        SonarrApp.stop()
        NSApp.terminate(self)
    }
}
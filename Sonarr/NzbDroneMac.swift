import Cocoa


class NzbDroneMac: NSObject, NSApplicationDelegate, NSURLDownloadDelegate, NSMenuDelegate {
    
    var statusItem: NSStatusItem!
    var statusMenu: NSMenu!
    
    var update_file = ""
    var appSupportDir: String!
    var binDir: String!
    
    var error: NSError?
    
    let monoPath = "/usr/bin/mono"
    var monoVersion = "0.0.0"
    
    let tarPath = "/usr/bin/tar"
    let stringsPath = "/usr/bin/strings"
    
    let webInterfaceUrl = NSURL(string: "http://localhost:8989/")
    let homepageUrl = NSURL(string: "http://nzbdrone.com/")
    let monoDownloadPage = NSURL(string: "http://www.go-mono.com/mono-downloads/download.html")
    
    var daemonTask = NSTask()
    
    init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        
        if NSFileManager.defaultManager().fileExistsAtPath(monoPath) {
            let monoVerString = shellcmd(monoPath, "--version")
            
            if let matches = monoVerString =~ "version ([0-9]+\\.[0-9]+\\.[0-9])" {
                monoVersion = matches[0]
            }
        }
        println("Mono version: \(monoVersion)")
        
        if monoVersion < "3.2.4" {
            let alert = NSAlert()
            alert.addButtonWithTitle("Download")
            alert.addButtonWithTitle("Cancel")
            alert.messageText = "NzbDrone requires a current version of the Mono runtime environment to execute."
            alert.informativeText = "Would you like to download and install the Mono Runtime now?"
            if alert.runModal() == NSAlertFirstButtonReturn {
                // http://download.mono-project.com/archive/
                NSWorkspace.sharedWorkspace().openURL(monoDownloadPage)
            }
        }
        
        // Initialize our directories
        appSupportDir = getAppSupportDirectory(.LocalDomainMask, "NzbDrone")
        if !appSupportDir {
            appSupportDir = getAppSupportDirectory(.UserDomainMask, "NzbDrone")
            if !appSupportDir {
                appSupportDir = NSHomeDirectory()
            }
        }
        println("appSupportDir = \(appSupportDir)")
        
        binDir = appSupportDir.stringByAppendingPathComponent("bin")
        NSFileManager.defaultManager().createDirectoryAtPath(binDir, withIntermediateDirectories: true, attributes: nil, error: nil)
        
        NSFileManager.defaultManager().createSymbolicLinkAtPath(
            NSHomeDirectory().stringByAppendingPathComponent("/.config/NzbDrone"),
            withDestinationPath: appSupportDir, error: nil)
        
        
        // Create the Menu
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
        statusMenu = NSMenu(title: "NzbDrone")
        statusMenu.autoenablesItems = false
        
        statusItem.image = NSImage(named: "icon_black_16.png")
        statusItem.alternateImage = NSImage(named: "icon_white_16.png")
        statusItem.highlightMode = true
        
        let statusMenuItem = statusMenu.addItemWithTitle("Status", action: "runDaemonAction:", keyEquivalent: "")
        statusMenuItem.enabled = false
        statusMenu.addItem(NSMenuItem.separatorItem())
        
        statusMenu.addItemWithTitle("About NzbDrone", action: "orderFrontStandardAboutPanel:", keyEquivalent: "")
        statusMenu.addItem(NSMenuItem.separatorItem())
        
        statusMenu.addItemWithTitle("Web Interface", action: "showWebInterfaceAction:", keyEquivalent: "")
        statusMenu.addItemWithTitle("Homepage", action: "homepageAction:", keyEquivalent: "")
        //statusMenu.addItemWithTitle("Downloads", action: "downloadsAction:", keyEquivalent: "")
        statusMenu.addItem(NSMenuItem.separatorItem())

        statusMenu.addItemWithTitle("Check for Update", action: "updateNzbDrone:", keyEquivalent: "")
        
        let loginMenuItem = statusMenu.addItemWithTitle("Run At Login", action: "runAtLoginAction:", keyEquivalent: "")
        if LoginItems.containsThisApp() {
            loginMenuItem.state = NSOnState
        } else {
            loginMenuItem.state = NSOffState
        }
        
        statusMenu.addItem(NSMenuItem.separatorItem())
        
        statusMenu.addItemWithTitle("Quit NzbDrone", action: "exitAction:", keyEquivalent: "")
        
        statusItem.menu = statusMenu
        
        statusMenu.delegate = self
        
        let nzbDronePath = binDir + "/NzbDrone.exe"
        if NSFileManager.defaultManager().fileExistsAtPath(nzbDronePath) == false {
            updateNzbDrone(nil)
        } else {
            runDaemon()
        }
    }
    
    func menuWillOpen(menu: NSMenu!) {
        let statusItem = menu.itemAtIndex(0)
        
        if daemonTask.running {
            statusItem.title = "Running"
            statusItem.enabled = false
        } else {
            statusItem.title = "Start NzbDrone"
            statusItem.enabled = true
        }
    }
    
    func updateNzbDrone(sender: NSMenuItem!) {
        
        var current_version = "0.0.0.0"
        
        let exe_strings = shellcmd("/usr/bin/strings", "\(binDir)/NzbDrone.exe")
        
        if let matches = exe_strings =~ "^([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)$" {
            current_version = matches[0]
        }
        
        println("Current version: " + current_version)
        
        // Download latest binary package
        // http://update.nzbdrone.com/v2/master/osx/NzbDrone.master.osx.tar.gz
        
        let update_root = "http://update.nzbdrone.com/v2/master/osx/"
        
        // Find newest version
        var newest_version = ""
        if let index_page = String.stringWithContentsOfURL(
            NSURL(string: update_root),
            encoding: NSUTF8StringEncoding, error: &error) {
                
                if error { println("error: " + error!.localizedDescription) }
                
                if let matches = index_page =~ "(?:\"NzbDrone.master.)(.*)(?:.osx.tar.gz\")" {
                    // sort version numbers from highest to lowest
                    let versions = sorted(matches, >)
                    newest_version = versions[0]
                }
        }
        
        println("Newest version: " + newest_version)
        update_file = NSTemporaryDirectory() + "NzbDrone.master.\(newest_version).osx.tar.gz"
        println("Update File: " + update_file)
        
        if current_version >= newest_version {
            println("No update necessary.")
            return()
        }
        
        let alert = NSAlert()
        alert.addButtonWithTitle("Download")
        alert.addButtonWithTitle("Cancel")
        alert.messageText = "A new version of NzbDrone is available."
        alert.informativeText = "Current version:\t\(current_version)\nAvailable version:\t\(newest_version)"
        if alert.runModal() == NSAlertSecondButtonReturn {
            return;
        }
        
        // Create request
        let urlRequest = NSURLRequest(URL: NSURL(string: update_root + update_file.lastPathComponent) )
        
        // Create the connection with the request and start loading the data.
        let urlDownload = NSURLDownload(request: urlRequest, delegate: self)
        
        println("Request URL: " + urlRequest.URL.description)
        
        urlDownload.setDestination(update_file, allowOverwrite: true)
        
    }
    
    func downloadDidFinish(download: NSURLDownload!) {
        
        println("Download finished: " + update_file)
        
        shellcmd(tarPath, "-x", "-C", appSupportDir.stringByAppendingPathComponent("bin"), "-f", update_file, "--strip-components=1")
        
        println("Finish extracting.")
        
        NSFileManager.defaultManager().removeItemAtPath(update_file, error: &error)
        if error { println("error: " + error!.localizedDescription) }
        
        let exe_strings = shellcmd(stringsPath, "\(binDir)/NzbDrone.exe")
        
        if let matches = exe_strings =~ "^([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)$" {
            println("Version: " + matches[0])
        }
        
        if daemonTask.running {
            daemonTask.terminate()
            daemonTask.waitUntilExit()
        }
        
        runDaemon()
    }
    
    func download(download: NSURLDownload!, didFailWithError error: NSError!) {
        println("Download failed: " + error.localizedDescription)
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }
    
    func showWebInterfaceAction(sender: NSMenuItem!) {
        NSWorkspace.sharedWorkspace().openURL(webInterfaceUrl)
    }
    
    func homepageAction(sender: NSMenuItem!) {
        NSWorkspace.sharedWorkspace().openURL(homepageUrl)
    }
    
    func runAtLoginAction(sender: NSMenuItem!) {
        
        if LoginItems.containsThisApp() {
            LoginItems.removeThisApp();
            sender.state = NSOffState
        } else {
            LoginItems.addThisApp();
            sender.state = NSOnState
        }
    }
    
    func runDaemonAction(sender: NSMenuItem!) {
        runDaemon()
    }
    
    func runDaemon() {
        
        let nzbDronePath = binDir + "/NzbDrone.exe"
        
        if NSFileManager.defaultManager().fileExistsAtPath(monoPath) == false {
            println("Mono not installed!")
            return
        }
        if NSFileManager.defaultManager().fileExistsAtPath(nzbDronePath) == false {
            println("NzbDrone daemon not installed!")
            return
        }

        if daemonTask.running {
            println("NzbDrone daemon is already running.")
            return
        }
        
        daemonTask = NSTask()
        
        daemonTask.launchPath = monoPath
        daemonTask.arguments = [nzbDronePath]
        
        daemonTask.launch()
        
        let statusMenuItem = statusMenu.itemAtIndex(0)
        statusMenuItem.title = "Running"
        statusMenuItem.enabled = false
    }
    
    func exitAction(sender: NSMenuItem!) {
        
        if daemonTask.running {
            daemonTask.terminate()
        }
        
        exit(1)
    }
    
}

//
//  MonoDialog.swift
//  Sonarr
//
//  Created by Jeff Barnes on 12/31/14.
//  Copyright (c) 2014 Sonarr. All rights reserved.
//

import Cocoa

class MonoDialog: NSWindowController, NSURLDownloadDelegate {


    @IBOutlet weak var messageText: NSTextField!
    @IBOutlet weak var infoText: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var downloadButton: NSButton!
    
    let monoUrl = "http://download.mono-project.com/archive/3.10.0/macos-10-x86/MonoFramework-MRE-3.10.0.macos10.xamarin.x86.pkg"
    
    let monoDownloadPage = NSURL(string: "http://www.go-mono.com/mono-downloads/download.html")!
    
    var downloadSize: Int64 = 0
    var downloadProgress: Int64 = 0
    
    let byteFormatter = NSByteCountFormatter()
    
    var downloadFile = ""
    
    var asyncShell: AsyncShell?
    
    let logFileName = "monoInstall.log"
    
    var urlDownload: NSURLDownload?
    
    var callback: (()->())?
    
    
    class func isMonoUpToDate() -> Bool {
        
        let monoPath = "/usr/bin/mono"
        
        var monoVersion = "0.0.0"
        var monoMajor = 0
        var monoMinor = 0
        
        if NSFileManager.defaultManager().fileExistsAtPath(monoPath) {
            let monoVerString = shellCmd(monoPath, "--version")
            
            if let matches = monoVerString =~ "version (([0-9]+)\\.([0-9]+)\\.([0-9]+))" {
                monoVersion = matches[0]
                monoMajor = matches[1].toInt()!  // fixme
                monoMinor = matches[2].toInt()!
                //NSLog("Mono major: \(matches[1])")
                //NSLog("Mono minor: \(matches[2])")
            }
        }
        NSLog("Mono version: \(monoVersion)")
        
        if (monoMajor < 3) || (monoMajor == 3 && monoMinor < 10) {
            return false
        } else {
            return true
        }
    }
    
    func showDialog(callback: (()->())?) {
        
        if !NSApp.isActive {
            NSApp.activateIgnoringOtherApps(true)
        }
        
        self.callback = callback
        self.window!.center()
        self.window!.makeKeyAndOrderFront(NSApplication.sharedApplication())
    }
    
    @IBAction func cancelAction(sender: AnyObject) {
        NSLog("Mono installation canceled.")
        urlDownload?.cancel()
        self.close()
        callback?()
    }
    
    @IBAction func downloadAction(sender: AnyObject) {
        downloadButton.enabled = false
        
        let filename = "MonoFramework-MRE-3.10.0.macos10.xamarin.x86.debug.pkg"
        
        let downloadDir = NSFileManager.defaultManager().URLForDirectory(
            .DownloadsDirectory, inDomain: .UserDomainMask,
            appropriateForURL: nil, create: true, error: nil)!
        
        downloadFile = downloadDir.path!.stringByAppendingPathComponent(filename)
        
        if NSFileManager.defaultManager().fileExistsAtPath(downloadFile) {
        
            NSLog("File found: \(downloadFile)")
            NSLog("Skipping download.")
            
            startInstall()
        
        } else {
        
            startDownload()
        }
    }
    
    
    func startDownload() {
        
        progressBar.indeterminate = false
        
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        progressBar.hidden = false
        
        byteFormatter.zeroPadsFractionDigits = true
        
        messageText.stringValue = "Downloading Mono..."
        
        // Create request
        let urlRequest = NSURLRequest(URL: NSURL(string:self.monoUrl)! )
        
        // Create the connection with the request and start loading the data.
        urlDownload = NSURLDownload(request: urlRequest, delegate: self)
        
        NSLog("Request URL: " + urlRequest.URL!.description)
        
    }
    
    
    func download(download: NSURLDownload, didFailWithError error: NSError) {
        NSLog("Download failed: " + error.localizedDescription)
    }
    
    
    func download(download: NSURLDownload, decideDestinationWithSuggestedFilename filename: String) {
        
        NSLog("Recieved suggested filename: \(filename)")
        
        let downloadDir = NSFileManager.defaultManager().URLForDirectory(
            .DownloadsDirectory, inDomain: .UserDomainMask,
            appropriateForURL: nil, create: true, error: nil)!
        
        NSLog("Download path: \(downloadDir.path!)")
        
        let destFile = downloadDir.path!.stringByAppendingPathComponent(filename)
        download.setDestination(destFile, allowOverwrite: false)
        
    }
    
    
    func download(download: NSURLDownload, didCreateDestination path: String) {
        
        downloadFile = path
        
        NSLog("Target file: \(downloadFile)")
    }
    
    
    func download(download: NSURLDownload, didReceiveResponse response: NSURLResponse) {
        
        NSLog("Recieved response with expected length: \(response.expectedContentLength)")
        
        downloadSize = response.expectedContentLength
        
        progressBar.maxValue = Double(downloadSize)
    }
    
    
    func download(download: NSURLDownload, didReceiveDataOfLength length: Int) {
        
        //NSLog("Recieving data. Incoming Size: \(length)  Total Size: \(progressBar.doubleValue)")
        
        progressBar.doubleValue += Double(length)
        
        downloadProgress += length
        
        let downloadSizeStr = byteFormatter.stringFromByteCount(downloadSize)
        let downloadProgressStr = byteFormatter.stringFromByteCount(downloadProgress)
        
        infoText.stringValue = "Recived \(downloadProgressStr) of \(downloadSizeStr)."
    }
    
    
    func downloadDidFinish(download: NSURLDownload) {
        
        NSLog("Download finished.")

        startInstall()
    }

    func startInstall() {
        messageText.stringValue = "Installing Mono..."
        
        progressBar.indeterminate = false
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        progressBar.hidden = false
        
        let logFile = appSupportDir().stringByAppendingPathComponent(logFileName)
        shellCmd("/usr/bin/touch", logFile)  // Make sure the log file is readable by user process
        
        let finishAction = { (output: String) -> () in
            self.asyncShell?.terminate()
            self.asyncShell = nil
            NSLog("Install complete.")
            
            if self.downloadFile.rangeOfString("debug") == nil {
                NSLog("Removing Mono download file.")
                NSFileManager.defaultManager().removeItemAtPath(self.downloadFile, error: nil)
            }
            self.close()
            self.callback?()
        }
        asyncSudoShellCmd(finishAction, "/usr/sbin/installer", "-verboseR", "-pkg", downloadFile, "-target", "/", ">", shellQuotedString(logFile))

        
        let outputAction = { (output: String) -> () in
            for line in output.componentsSeparatedByString("\n") {
                
                if let range = line.rangeOfString("installer:PHASE:") {
                    var phase = line
                    phase.removeRange(range)
                    self.infoText.stringValue = phase
                }
                if let range = line.rangeOfString("installer:%") {
                    var percentStr = line
                    percentStr.removeRange(range)
                    self.progressBar.doubleValue = (percentStr as NSString).doubleValue
                }
                NSLog(line)
            }
        }
        asyncShell = AsyncShell(stdOutAction: outputAction)
        

        asyncShell!.shellCmd("/usr/bin/tail", "-n", "0", "-f", logFile)
    }
}

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
    

    let monoUrl = NSURL(string: "http://download.mono-project.com/archive/mdk-latest.pkg")!
    static let minMonoVersion = "4.0.4"
    
    var downloadSize: Int64 = 0
    var downloadProgress: Int64 = 0
    
    let byteFormatter = NSByteCountFormatter()
    
    var downloadFile = NSURL(fileURLWithPath: "")
    
    var asyncShell: AsyncShell?
    
    let logFileName = "monoInstall.log"
    
    var urlDownload: NSURLDownload?
    
    var callback: (()->())?
    
    class func isGreaterThanMinimumVersion(minVersion: String, currentVersion: String) -> Bool {
        
        let minTokens = minVersion.characters.split{$0 == "."}.map{Int(String($0))}
        let curTokens = currentVersion.characters.split{$0 == "."}.map{Int(String($0))}
        
        for (minToken, curToken) in zip(minTokens, curTokens) {
            print("minToken \(minToken), curToken \(curToken)")
            if curToken < minToken {
                return false
            }
            if curToken > minToken {
                return true
            }
        }
        return true
    }
    
    class func isMonoUpToDate() -> Bool {
        
        var monoVersion = "0.0.0"

        if monoPath.checkResourceIsReachable() {
            let monoVerString = shellCmd(monoPath.path!, args: "--version")
            
            if let matches = monoVerString =~ "version (([0-9]+)\\.([0-9]+)\\.([0-9]+))" {
                monoVersion = matches[0]
            }
        }
        NSLog("Mono version: \(monoVersion)")

        return isGreaterThanMinimumVersion(minMonoVersion, currentVersion: monoVersion)
    }
    
    func showDialog(callback: (()->())?) {
        
        if !NSApp.active {
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
        
        let filename = "mdk-latest.pkg"
        
        let downloadDir = try! NSFileManager.defaultManager().URLForDirectory(
            .DownloadsDirectory, inDomain: .UserDomainMask,
            appropriateForURL: nil, create: true)
        
        downloadFile = downloadDir.URLByAppendingPathComponent(filename)
        
        if downloadFile.checkResourceIsReachable() {
        
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
        let urlRequest = NSURLRequest(URL: monoUrl)
        
        // Create the connection with the request and start loading the data.
        urlDownload = NSURLDownload(request: urlRequest, delegate: self)
        
        NSLog("Request URL: " + urlRequest.URL!.description)
        
    }
    
    
    func download(download: NSURLDownload, didFailWithError error: NSError) {
        NSLog("Download failed: " + error.localizedDescription)
    }
    
    
    func download(download: NSURLDownload, decideDestinationWithSuggestedFilename filename: String) {
        
        NSLog("Recieved suggested filename: \(filename)")
        
        let downloadDir = try! NSFileManager.defaultManager().URLForDirectory(
            .DownloadsDirectory, inDomain: .UserDomainMask,
            appropriateForURL: nil, create: true)
        
        NSLog("Download path: \(downloadDir.path!)")
        
        let destFile = downloadDir.URLByAppendingPathComponent(filename)
        download.setDestination(destFile.path!, allowOverwrite: false)
        
    }
    
    
    func download(download: NSURLDownload, didCreateDestination path: String) {
        
        downloadFile = NSURL(fileURLWithPath: path)
        
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
        
        let logFile = appSupportDir().URLByAppendingPathComponent(logFileName)
        shellCmd("/usr/bin/touch", args: logFile.path!)  // Make sure the log file is readable by user process
        
        let finishAction = { (output: String) -> () in
            self.asyncShell?.terminate()
            self.asyncShell = nil
            NSLog("Install complete.")
            
            if self.downloadFile.path!.rangeOfString("debug") == nil {
                NSLog("Removing Mono download file.")
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(self.downloadFile)
                } catch _ {
                }
            }
            self.close()
            self.callback?()
        }
        asyncSudoShellCmd(finishAction, cmd: "/usr/sbin/installer", args: "-verboseR", "-pkg", downloadFile.path!, "-target", "/", ">", shellQuotedString(logFile.path!))

        
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
        

        asyncShell!.shellCmd("/usr/bin/tail", "-n", "0", "-f", logFile.path!)
    }
}

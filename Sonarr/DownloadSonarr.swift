//
//  DownloadSonarr.swift
//  Sonarr
//
//  Created by Jeff Barnes on 1/4/15.
//  Copyright (c) 2015 Sonarr. All rights reserved.
//

import Foundation

// Class to download the latest Sonarr app files.  This is primarily for testing, future distributions will have these
// files included with the app bundle.  Hence, this is console only, no GUI.

class DownloadSonarr: NSObject, NSURLDownloadDelegate {
    
    let sonarrUrl = "http://update.nzbdrone.com/v2/master/osx/NzbDrone.master.osx.tar.gz"
    var downloadFile = ""
    
    let binDir = NSBundle.mainBundle().resourcePath!.stringByAppendingPathComponent("bin")
    
    var callback: (()->())?
    
    func startDownload(callback: (()->())?) {
        
        self.callback = callback

        // Create request
        let urlRequest = NSURLRequest(URL: NSURL(string:sonarrUrl)! )
        
        // Create the connection with the request and start loading the data.
        let urlDownload = NSURLDownload(request: urlRequest, delegate: self)
        
        NSLog("Request URL: " + urlRequest.URL.description)
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
    }
    
    
    func download(download: NSURLDownload, didReceiveDataOfLength length: Int) {
        
        print(".")
    }
    
    
    func downloadDidFinish(download: NSURLDownload) {
        var error: NSError?
        
        println()
        NSLog("Download finished: " + downloadFile)
        
        NSFileManager.defaultManager().createDirectoryAtPath(binDir, withIntermediateDirectories: true, attributes: nil, error: &error)
        if (error != nil) { NSLog("error: " + error!.localizedDescription) }
        
        shellCmd("/usr/bin/tar", "-x", "-C", binDir, "-f", downloadFile, "--strip-components=1")
        
        NSLog("Finish extracting.")
        
        NSFileManager.defaultManager().removeItemAtPath(downloadFile, error: &error)
        if (error != nil) { NSLog("error: " + error!.localizedDescription) }
        
        let exe_strings = shellCmd("/usr/bin/strings", "\(binDir)/NzbDrone.exe")
        
        if let matches = exe_strings =~ "^([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)$" {
            NSLog("Version: " + matches[0])
        }
        
        callback?()
    }
    
}
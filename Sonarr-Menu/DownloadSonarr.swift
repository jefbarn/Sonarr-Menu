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
    
    var sonarrUrl = NSURL(string: "http://download.sonarr.tv/v2/master/osx/NzbDrone.master.osx.tar.gz")!
    var downloadFile = ""
    
    let binDir = NSBundle.mainBundle().resourceURL!.URLByAppendingPathComponent("bin")
    
    var callback: (()->())?
    
    var branch: String = "master"
    
    func startDownload(branch: String, callback: (()->())?) {
        
        self.callback = callback
        self.branch = branch
        sonarrUrl = NSURL(string: "http://download.sonarr.tv/v2/\(branch)/osx/NzbDrone.\(branch).osx.tar.gz")!

        // Create request
        let urlRequest = NSURLRequest(URL: sonarrUrl )
        
        // Create the connection with the request and start loading the data.
        _ = NSURLDownload(request: urlRequest, delegate: self)
        
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
        
        downloadFile = path
        
        NSLog("Target file: \(downloadFile)")
    }
    
    
    func download(download: NSURLDownload, didReceiveResponse response: NSURLResponse) {
        
        NSLog("Recieved response with expected length: \(response.expectedContentLength)")
    }
    
    
    func download(download: NSURLDownload, didReceiveDataOfLength length: Int) {
        
        print(".", terminator: "")
    }
    
    
    func downloadDidFinish(download: NSURLDownload) {
        
        print("")
        NSLog("Download finished: " + downloadFile)
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(binDir, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Error: " + error.localizedDescription)
        }
        
        shellCmd("/usr/bin/tar", args: "-x", "-C", binDir.path!, "-f", downloadFile, "--strip-components=1")
        
        NSLog("Finish extracting.")
        
        do {
            try NSFileManager.defaultManager().removeItemAtPath(downloadFile)
        } catch let error as NSError {
            NSLog("Error: " + error.localizedDescription)
        }
        
        /*
        let exe_strings = shellCmd("/usr/bin/strings", args: "\(binDir)/NzbDrone.exe")
        
        if let matches = exe_strings =~ "^([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)$" {
            NSLog("Version: " + matches[0])
        } */
        
        callback?()
    }
    
}
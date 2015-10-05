import Cocoa


func shellCmd(cmd: String, args: String...) -> String {
    
    let task = NSTask()
    let out_pipe = NSPipe()
    
    task.launchPath = cmd
    task.arguments = args
    
    task.standardOutput = out_pipe
    
    task.launch()
    
    task.waitUntilExit()
    
    let out_data = out_pipe.fileHandleForReading.readDataToEndOfFile()
    let out_string = NSString(data: out_data, encoding: NSUTF8StringEncoding)
    
    return out_string as! String
}


class AsyncShell : NSObject {  // objc?
    
    var taskRunning = false
    var output = ""
    var stdErr = ""
    
    var stdOutAction: ((String)->())?
    var stdErrorAction: ((String)->())?
    var completeAction: (()->())?
    
    let task = NSTask()
    let noteCenter = NSNotificationCenter.defaultCenter()
    
    let outPipe   = NSPipe()
    let errorPipe = NSPipe()
    
    init(stdOutAction: ((String)->())? = nil, stdErrorAction: ((String)->())? = nil, completeAction: (()->())? = nil) {
        self.stdOutAction = stdOutAction
        self.stdErrorAction = stdErrorAction
        self.completeAction = completeAction
    }
    
    deinit {
        NSLog("AsyncShell deinit")
        noteCenter.removeObserver(self)
    }
    
    func shellCmd(cmd: String, _ args: String...) {
        
        task.launchPath = cmd
        task.arguments  = args
        
        let fhOut   = outPipe.fileHandleForReading
        let fhError = errorPipe.fileHandleForReading
        
        noteCenter.addObserver(self, selector: "notifiedForStdOutput:", name:"NSFileHandleReadCompletionNotification", object: fhOut)
        noteCenter.addObserver(self, selector: "notifiedForStdError:",  name:"NSFileHandleReadCompletionNotification", object: fhError)
        noteCenter.addObserver(self, selector: "notifiedForComplete:",  name:"NSTaskDidTerminateNotification", object: task)
        
        task.standardOutput = outPipe
        task.standardError  = errorPipe
        
        taskRunning = true
        
        NSLog("Running task: " + cmd + " " + args.joinWithSeparator(" "))
        
        task.launch()
        
        
        fhOut.readInBackgroundAndNotify()
        fhError.readInBackgroundAndNotify()
    }
    
    
    func notifiedForStdOutput(notification: NSNotification) {
        
        if let data = notification.userInfo?[NSFileHandleNotificationDataItem] as? NSData {
            if let outString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
                output += outString
                stdOutAction?(outString)
            }
        }
        
        if taskRunning {
            if let fileHandle = notification.object as? NSFileHandle {
                fileHandle.readInBackgroundAndNotify()
            }
        }
        
        
    }
    
    
    func notifiedForStdError(notification: NSNotification) {
        
        if let data = notification.userInfo?[NSFileHandleNotificationDataItem] as? NSData {
            if let outString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
                stdErr += outString
                stdErrorAction?(outString)
            }
        }
        
        if taskRunning {
            if let fileHandle = notification.object as? NSFileHandle {
                fileHandle.readInBackgroundAndNotify()
            }
        }
    }
    
    
    func notifiedForComplete(notification: NSNotification) {
        
        taskRunning = false
        
        if let task = notification.object as? NSTask {
            if task.terminationStatus == 0 {
                NSLog("Task terminated successfully.")
            } else {
                NSLog("Task terminated with non-zero exit code: \(task.terminationStatus)")
            }
        } else {
            NSLog("Error, no task object in termination notification.")
        }
        
        completeAction?()
    }
    
    func terminate() {
        task.terminate()
    }
}


func sudoShellCmd(cmd: String, args: String...) -> String?
{

    let fullScript = String(format: "'%@' %@", cmd, args.joinWithSeparator(" "))
    
    let script = String(format: "do shell script \"%@\" with administrator privileges", fullScript)
    var errorInfo: NSDictionary?
    
    if let result = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo).stringValue {
        return result
    }
    
    if let errorStr = errorInfo?.valueForKey(NSAppleScriptErrorMessage) as? NSString {
        
        NSLog("Error running process as administrator: \(errorStr)")
    } else {
        
        NSLog("Error running process as administrator.")
    }

    return nil
}


func asyncSudoShellCmd(callback: ((String)->())?, cmd: String, args: String...)
{
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    dispatch_async(queue) {
        
        let fullScript = String(format: "'%@' %@", cmd, args.joinWithSeparator(" "))
        
        let script = String(format: "do shell script \"%@\" with administrator privileges", fullScript)
        var errorInfo: NSDictionary?
           
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo).stringValue {
            
            dispatch_async(dispatch_get_main_queue()) {
                callback?(result)
                return
            }
            return
        }
        
        if let errorStr = errorInfo?.valueForKey(NSAppleScriptErrorMessage) as? NSString {
            
            NSLog("Error running process as administrator: \(errorStr)")
        } else {
            
            NSLog("Error running process as administrator.")
        }

        dispatch_async(dispatch_get_main_queue()) {
            callback?("")
            return
        }
        return
    }
}


infix operator =~ {}
func =~ (input: String, pattern: String) -> [String]? {
    let nsInput = input as NSString
    let regex = try! NSRegularExpression(pattern: pattern, options: .AnchorsMatchLines)
    let results = regex.matchesInString(nsInput as String, options: [], range: NSMakeRange(0, nsInput.length) ) as [NSTextCheckingResult]
    
    if (results.count > 0) {
        var values = [String]()
        
        for result in results {
            for i in 1..<result.numberOfRanges {
                let range = result.rangeAtIndex(i)
                
                values.append(nsInput.substringWithRange(range))
            }
        }
        return values
    } else {
        return nil
    }
}


func appSupportDir() -> NSURL {
    
    let bundleName = "Sonarr"
    
    do {
        let SupportDirUrl = try NSFileManager.defaultManager().URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        
        let path = SupportDirUrl.URLByAppendingPathComponent(bundleName)
        
        try NSFileManager.defaultManager().createDirectoryAtURL(path, withIntermediateDirectories: true, attributes: nil)

        return path

    } catch let error as NSError {
        NSLog("Unable to find or create application support directory: ", error.localizedDescription)
        
        exit(1)
    }
}


func shellQuotedString(string: String) -> String {
    return String(format: "'%@'", string.stringByReplacingOccurrencesOfString("'", withString:"'\\''"))
}


func monitorChangesToFile(filename: NSURL, handler: ()->()) -> dispatch_source_t? {

    func printFlags(flags: UInt) -> String {
        var output = ""
        if (flags & DISPATCH_VNODE_DELETE) != 0 { output += "DISPATCH_VNODE_DELETE:" }
        if (flags & DISPATCH_VNODE_WRITE)  != 0 { output += "DISPATCH_VNODE_WRITE:" }
        if (flags & DISPATCH_VNODE_EXTEND) != 0 { output += "DISPATCH_VNODE_EXTEND:" }
        if (flags & DISPATCH_VNODE_ATTRIB) != 0 { output += "DISPATCH_VNODE_ATTRIB:" }
        if (flags & DISPATCH_VNODE_LINK)   != 0 { output += "DISPATCH_VNODE_LINK:" }
        if (flags & DISPATCH_VNODE_RENAME) != 0 { output += "DISPATCH_VNODE_RENAME:" }
        if (flags & DISPATCH_VNODE_REVOKE) != 0 { output += "DISPATCH_VNODE_REVOKE:" }
        return output
    }
    
    NSLog("Monitoring \(filename) for changes.")
    
    var buffer = Array<Int8>(count: Int(PATH_MAX), repeatedValue: 0)
    filename.getFileSystemRepresentation(&buffer, maxLength: Int(PATH_MAX))
    
    let fileDescriptor = open(&buffer, O_EVTONLY)
    if (fileDescriptor >= 0) {
    
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
        if let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, UInt(fileDescriptor), DISPATCH_VNODE_WRITE, queue) {
            
            dispatch_source_set_event_handler(source) {
                //println("Dispatch Event (handle=\(dispatch_source_get_handle(source))): \(printFlags(dispatch_source_get_data(source)))")
                handler()
            }
            
            dispatch_source_set_cancel_handler(source) {
                close(fileDescriptor)
                return
            }

            dispatch_resume(source)
            return source
        } else {
            NSLog("Error: could not create file event dispatch source.")
            close(fileDescriptor)
        }
        
    } else {
        NSLog("Error: could not open \(filename) for reading.")
    }
    return nil
}

extension NSURL {
    
    func checkResourceIsReachable() -> Bool {
        var error: NSError?
        let reachable = self.checkResourceIsReachableAndReturnError(&error)
        if !reachable {
            //NSLog("Error checking resource reachable: " + error!.localizedDescription)
        }
        return reachable
    }
}

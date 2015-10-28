import Foundation


func shellcmd(cmd: String, args: String...) -> String {
    
    let task = NSTask()
    let out_pipe = NSPipe()
    
    task.launchPath = cmd
    task.arguments = args
    
    task.standardOutput = out_pipe
    
    task.launch()
    
    task.waitUntilExit()
    
    let out_data = out_pipe.fileHandleForReading.readDataToEndOfFile()
    let out_string = NSString(data: out_data, encoding: NSUTF8StringEncoding)
    
    return out_string
}


operator infix =~ {}
func =~ (input: String, pattern: String) -> [String]? {
    let regex = NSRegularExpression(pattern: pattern, options: .AnchorsMatchLines, error: nil)
    let results = regex.matchesInString(input,
        options: nil,
        range: NSMakeRange(0, countElements(input))
        )! as [NSTextCheckingResult]
    
    if (results.count > 0) {
        var values:Array<String> = []
        
        for result in results {
            for i in 1..<result.numberOfRanges {
                let range = result.rangeAtIndex(i)
                
                values += input
                    .substringFromIndex(range.location)
                    .substringToIndex(range.length)
            }
        }
        return values
    } else {
        return nil
    }
}


func getAppSupportDirectory(domain: NSSearchPathDomainMask, bundle: String) -> String? {
    
    var error: NSError?
    
    var URL = NSFileManager.defaultManager().URLForDirectory(
        .ApplicationSupportDirectory, inDomain: domain,
        appropriateForURL: nil, create: true, error: &error)
    if error {
        //println("error: " + error!.localizedDescription)
        return nil
    }
    
    let dir = URL.URLByAppendingPathComponent(bundle).path
    
    NSFileManager.defaultManager().createDirectoryAtPath(dir, withIntermediateDirectories: true, attributes: nil, error: &error)
    if error {
        //println("error: " + error!.localizedDescription)
        return nil
    }
    
    return dir
}

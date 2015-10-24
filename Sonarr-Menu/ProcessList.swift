//
//  ProcessList.swift
//  Sonarr-Menu
//
//  Created by Jeff Barnes on 10/22/15.
//  Copyright © 2015 Sonarr. All rights reserved.
//

import Foundation


func getBSDProcessList() throws -> [kinfo_proc] {
    
    var name = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
    
    for var index = 0; index < 10; index++ {  // Only try 10 times
        
        // Call sysctl with a NULL buffer.
        
        var length = 0
        
        guard sysctl( &name, u_int(name.count), nil, &length, nil, 0) == 0 else {
            
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        var result = Array(count: length / strideof(kinfo_proc), repeatedValue: kinfo_proc())

        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again. (More processes got added between calls)
        
        guard sysctl( &name, u_int(name.count), &result, &length, nil, 0) == 0 else {

            if errno == ENOMEM {
                continue
            } else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            }
        }
        
        return result
    }
    
    // Max tries exhausted
    throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOMEM), userInfo: nil)
}


func getProcessArgs(pid: pid_t) -> String {
 
    var name = [CTL_KERN, KERN_PROCARGS2, pid]
    
    var argmax = 256 * 1024  // KERN_ARGMAX
    
    var buffer = Array<CChar>(count: argmax, repeatedValue: 0)
    
    sysctl(&name, u_int(name.count), &buffer, &argmax, nil, 0)
    
    let argc = Int(buffer[0])
    guard argc > 0 else {
        return ""
    }
    
    let splits = buffer.split(Int8(0))
    let args = splits[2..<argc+2]
    var exec = ""
    
    for arg in args {
        var cstring = Array(arg)
        cstring.append(Int8(0))    // Split strips off the null terminator, add it back
        let string = String.fromCString(cstring) ?? ""
        exec += string + " "
    }
    
    return exec
}
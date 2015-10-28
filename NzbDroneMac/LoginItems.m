#import "LoginItems.h"

@implementation LoginItems


+(void) addThisApp {
    
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    if (mainBundle == NULL) return;
    
    CFURLRef appUrl = CFBundleCopyBundleURL(mainBundle);
    if (appUrl == NULL) return;
    
    LSSharedFileListRef fileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (fileList) {

        LSSharedFileListItemRef item =
            LSSharedFileListInsertItemURL(fileList, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        
        if (item) {
            CFRelease(item);
        }
        
        CFRelease(fileList);
    }
    CFRelease(appUrl);
}


+(void) removeThisApp {
    
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    if (mainBundle == NULL) return;
    
    CFURLRef appUrl = CFBundleCopyBundleURL(mainBundle);
    if (appUrl == NULL) return;
    
    LSSharedFileListRef fileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (fileList) {
        UInt32 seedValue = 0;

        CFArrayRef loginItems = LSSharedFileListCopySnapshot(fileList, &seedValue);

        for (int i = 0; i < CFArrayGetCount(loginItems); i++) {
            
            LSSharedFileListItemRef listItem = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(loginItems, i);
            
            CFURLRef itemUrl = NULL;
            if (LSSharedFileListItemResolve(listItem, 0, &itemUrl, NULL) == noErr) {
                
                if (itemUrl) {
                    
                    if (CFEqual(appUrl, itemUrl)) {
                        LSSharedFileListItemRemove(fileList, listItem);
                    }
                    CFRelease(itemUrl);
                }
            }
        }
        
        CFRelease(loginItems);
        CFRelease(fileList);
    }
    CFRelease(appUrl);
}


+(BOOL) containsThisApp {
    
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    if (mainBundle == NULL) return FALSE;
    
    CFURLRef appUrl = CFBundleCopyBundleURL(mainBundle);
    if (appUrl == NULL) return FALSE;
    
    BOOL appFound = FALSE;
    
    LSSharedFileListRef fileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (fileList) {
        UInt32 seedValue = 0;
        
        CFArrayRef loginItems = LSSharedFileListCopySnapshot(fileList, &seedValue);
        
        for (int i = 0; i < CFArrayGetCount(loginItems); i++) {
            
            LSSharedFileListItemRef listItem = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(loginItems, i);
            
            CFURLRef itemUrl = NULL;
            if (LSSharedFileListItemResolve(listItem, 0, &itemUrl, NULL) == noErr) {
                
                if (itemUrl) {
                    
                    if (CFEqual(appUrl, itemUrl)) {
                        appFound = TRUE;
                    }
                    CFRelease(itemUrl);
                }
            }
        }
        
        CFRelease(loginItems);
        CFRelease(fileList);
    }
    CFRelease(appUrl);
    
    return appFound;
}


@end

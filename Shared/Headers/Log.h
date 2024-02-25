/*
    ObjC
        CLI
        Not CLI
    Not ObjC
        CLI
        Not CLI
*/

#ifdef __OBJC__
#include <Foundation/Foundation.h>

#if CLI

#define IALLog(format, ...) printf("[i] %s\n", [[NSString stringWithFormat:format, ##__VA_ARGS__] UTF8String])
#define IALLogErr(format, ...) printf("[x] %s\n", [[NSString stringWithFormat:format, ##__VA_ARGS__] UTF8String])

#else // not CLI

@interface NSDistributedNotificationCenter : NSNotificationCenter
@end

#define IALLog(format, ...) do { \
    NSString *message = [NSString stringWithFormat:(format), ##__VA_ARGS__]; \
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"[IALLog]" object:nil userInfo:@{@"file": @(__FILE__), @"line": @(__LINE__), @"message": message}]; \
} while(0)

#define IALLogErr(format, ...) do { \
    NSString *message = [NSString stringWithFormat:(format), ##__VA_ARGS__]; \
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"[IALLogErr]" object:nil userInfo:@{@"file": @(__FILE__), @"line": @(__LINE__), @"message": message}]; \
} while(0)

#endif /* CLI */

#else // not ObjC

#if CLI

#define IALLog(format, ...) printf("[i] " format "\n", ##__VA_ARGS__)
#define IALLogErr(format, ...) printf("[x] " format "\n", ##__VA_ARGS__)

#else // not CLI
#include <CoreFoundation/CoreFoundation.h>
extern CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);

#define IALLog(format, ...) do { \
    CFStringRef message = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR(format), ##__VA_ARGS__); \
    CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("[IALLog]"), NULL, (CFDictionaryRef)CFDictionaryCreate(kCFAllocatorDefault, (const void **)&(CFStringRef[]){CFSTR("message")}, (const void **)&message, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks), true); \
    CFRelease(message); \
} while(0)

#define IALLogErr(format, ...) do { \
    CFStringRef message = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR(format), ##__VA_ARGS__); \
    CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("[IALLogErr]"), NULL, (CFDictionaryRef)CFDictionaryCreate(kCFAllocatorDefault, (const void **)&(CFStringRef[]){CFSTR("message")}, (const void **)&message, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks), true); \
    CFRelease(message); \
} while(0)

#endif /* CLI */
#endif /* ObjC */

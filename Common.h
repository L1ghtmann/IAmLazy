#import "Log.h"

// https://stackoverflow.com/a/1746920 -- NSLocalizedString(str, nil) but with en fallback
#define bundle [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Strings"]
#define localize(str) [[NSBundle bundleWithPath:bundle] localizedStringForKey:str value:[[NSBundle bundleWithPath:[[NSBundle bundleWithPath:bundle] pathForResource:@"en" ofType:@"lproj"]] localizedStringForKey:str value:@"?" table:nil] table:nil]

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

// scale from iP7 size
#define scaleFactor (kWidth/375)

#define tmpDir @"/tmp/me.lightmann.iamlazy/"
#define backupDir @"/var/mobile/Documents/me.lightmann.iamlazy/"

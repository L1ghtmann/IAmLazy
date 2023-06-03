#import <rootless.h>
#import "Log.h"

#define localize(str) NSLocalizedStringWithDefaultValue(str, nil, [NSBundle mainBundle], str, nil)

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define scaleFactor (kWidth/375) // scale from iP7 size

#define tmpDir ROOT_PATH_NS(@"/tmp/me.lightmann.iamlazy/")
#define backupDir ROOT_PATH_NS(@"/var/mobile/Documents/me.lightmann.iamlazy/")

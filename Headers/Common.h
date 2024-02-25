#import <rootless.h>
#import <Log.h>

#define localize(str) NSLocalizedStringWithDefaultValue(str, nil, [NSBundle mainBundle], str, nil)

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define wScaleFactor (kWidth/375) // scale from iP7 size
#define hScaleFactor (kHeight/667) // scale from iP7 size

#define iPad() ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

// #define tmpDir ROOT_PATH_NS_VAR(@"/tmp/me.lightmann.iamlazy/") // has no w perms on palera1n??
#define tmpDir @"/tmp/me.lightmann.iamlazy/"
#define backupDir ROOT_PATH_NS_VAR(@"/var/mobile/Documents/me.lightmann.iamlazy/")

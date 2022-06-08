#import <UIKit/UIApplication.h>
#import <UIKit/UIScreen.h>
#import <NSTask.h>

#define tmpDir @"/tmp/me.lightmann.iamlazy/"
#define filesToCopy @"/tmp/me.lightmann.iamlazy/.filesToCopy"
#define backupDir @"/var/mobile/Documents/me.lightmann.iamlazy/"
#define logDir @"/var/mobile/Documents/me.lightmann.iamlazy/logs/"

#define dpkgInfoDir @"/var/lib/dpkg/info/"
#define aptListsDir @"/var/lib/apt/lists/"

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define scaleFactor (kWidth/375) // scale from iP7 size

#define container (kHeight - [[UIApplication sharedApplication] statusBarHeight])
#define cellHeight (container/6.5)

@interface UIApplication (Private)
-(double)statusBarHeight;
@end

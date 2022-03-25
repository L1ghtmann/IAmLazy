#import <UIKit/UIApplication.h>

#define tmpDir @"/tmp/me.lightmann.iamlazy/"
#define filesToCopy @"/tmp/me.lightmann.iamlazy/.filesToCopy"
#define backupDir @"/var/mobile/Documents/me.lightmann.iamlazy/"
#define logDir @"/var/mobile/Documents/me.lightmann.iamlazy/logs/"

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define container (kHeight - [[UIApplication sharedApplication] statusBarHeight])
#define cellHeight (container/2)

@interface UIApplication (Private)
-(double)statusBarHeight;
@end

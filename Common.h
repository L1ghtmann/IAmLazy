#import <UIKit/UIApplication.h>
#import <NSTask.h>

#define tmpDir @"/tmp/me.lightmann.iamlazy/"
#define gFilesToCopy @"/tmp/me.lightmann.iamlazy/.gfilesToCopy"
#define dFilesToCopy @"/tmp/me.lightmann.iamlazy/.dfilesToCopy"
#define targetDir @"/tmp/me.lightmann.iamlazy/.targetDir"
#define logDir @"/var/mobile/Documents/me.lightmann.iamlazy/logs/"
#define backupDir @"/var/mobile/Documents/me.lightmann.iamlazy/"

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define container (kHeight - [[UIApplication sharedApplication] statusBarHeight])
#define cellHeight (container/2.5)

@interface UIApplication (Private)
-(double)statusBarHeight;
@end

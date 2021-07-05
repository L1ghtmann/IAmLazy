#import <NSTask.h>

#define tmpDir @"/var/tmp/me.lightmann.iamlazy/"
#define filesToCopy @"/var/tmp/me.lightmann.iamlazy/filesToCopy.txt"
#define backupDir @"/var/mobile/Documents/me.lightmann.iamlazy/"

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define container (kHeight - [[UIApplication sharedApplication] statusBarHeight] - [[[(PreferencesAppController *)[UIApplication sharedApplication] rootController] navigationController] navigationBar].bounds.size.height)
#define cellHeight (container/3)

@interface UIApplication (Private)
-(double)statusBarHeight;
@end

@interface PreferencesAppController : UIApplication
-(UIViewController *)rootController;
@end

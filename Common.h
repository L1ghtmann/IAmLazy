#import <NSTask.h>

#define tmpDir @"/var/tmp/me.lightmann.iamlazy/"
#define filesToCopy @"/var/tmp/me.lightmann.iamlazy/.filesToCopy"
#define targetDirectory @"/var/tmp/me.lightmann.iamlazy/.targetDirectory"
#define backupDir @"/var/mobile/Documents/me.lightmann.iamlazy/"

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#define container (kHeight - [[UIApplication sharedApplication] statusBarHeight])
#define cellHeight (container/2.5)

@interface UIApplication (Private)
-(double)statusBarHeight;
@end


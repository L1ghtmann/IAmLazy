#import <UIKit/UIKit.h>
#import "IALManager.h"

@interface IALRootViewController : UITableViewController <UITabBarDelegate>
@property (nonatomic, retain) IALManager *manager;
-(void)selectedBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
@end

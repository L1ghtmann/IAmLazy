#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRootViewController : UITableViewController <UITabBarDelegate>
@property (nonatomic, retain) IALGeneralManager *manager;
-(void)selectedBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
@end

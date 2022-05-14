#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRootViewController : UITableViewController <UITabBarDelegate>
@property (nonatomic, retain) IALGeneralManager *manager;
@end

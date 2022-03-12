#import <UIKit/UIKit.h>

@interface IALRootViewController : UITableViewController <UITabBarDelegate>
-(void)selectedBackupWithFormat:(NSString *)format andFilter:(BOOL)filter;
-(void)makeDebBackupWithFilter:(BOOL)filter;
-(void)makeListBackupWithFilter:(BOOL)filter;
@end

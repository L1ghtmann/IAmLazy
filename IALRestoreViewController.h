#import <UIKit/UIKit.h>

@interface IALRestoreViewController : UITableViewController
-(void)selectedRestoreWithFormat:(NSString *)format andLatest:(BOOL)latest;
-(void)restoreDebBackupWithLatest:(BOOL)latest;
-(void)restoreListBackupWithLatest:(BOOL)latest;
@end

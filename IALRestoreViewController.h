#import <UIKit/UIKit.h>
#import "IALManager.h"

@interface IALRestoreViewController : UITableViewController
@property (nonatomic, retain) IALManager *manager;
-(void)restoreLatestBackup:(BOOL)latest ofType:(NSInteger)type;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
@end

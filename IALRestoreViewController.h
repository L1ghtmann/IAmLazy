#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRestoreViewController : UITableViewController
@property (nonatomic, retain) IALGeneralManager *manager;
-(void)restoreLatestBackup:(BOOL)latest ofType:(NSInteger)type;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
@end

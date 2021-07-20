#import <UIKit/UIKit.h>

@interface IALRootViewController : UITableViewController
-(void)showBackupSelection;
-(void)makeTweakBackupWithFilter:(BOOL)filter;
-(void)showRestoreSelection;
-(void)restoreFromBackup:(NSString *)backupName;
-(void)showOptions;
@end

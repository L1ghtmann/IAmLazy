#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALBackupsViewController : UITableViewController <UIDocumentPickerDelegate>
@property (nonatomic, retain) IALGeneralManager *generalManager;
@property (nonatomic, retain) NSMutableArray *backups;
-(void)refreshTable;
-(void)getBackups;
-(void)importBackup;
@end

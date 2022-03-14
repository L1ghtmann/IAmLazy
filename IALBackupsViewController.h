#import <UIKit/UIKit.h>

@interface IALBackupsViewController : UITableViewController <UIDocumentPickerDelegate>
@property (nonatomic, retain) NSMutableArray *backups;
-(void)refreshTable;
-(void)getBackups;
-(void)importBackup;
@end

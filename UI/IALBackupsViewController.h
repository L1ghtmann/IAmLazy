#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALBackupsViewController : UITableViewController <UIDocumentPickerDelegate>
@property (nonatomic, retain) IALGeneralManager *manager;
@property (nonatomic, retain) NSMutableArray *backups;
@end

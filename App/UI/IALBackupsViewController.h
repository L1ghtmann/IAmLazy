#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALBackupsViewController : UITableViewController <UIDocumentPickerDelegate> {
    IALGeneralManager *_manager;
    NSMutableArray<NSString *> *_backups;
}
@end

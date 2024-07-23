#import <UIKit/UIKit.h>

@class IALGeneralManager, IALRootViewController;

@interface IALBackupsViewController : UITableViewController <UIDocumentPickerDelegate> {
    IALGeneralManager *_manager;
    IALRootViewController *_rootVC;
    NSMutableArray<NSString *> *_backups;
}
@end

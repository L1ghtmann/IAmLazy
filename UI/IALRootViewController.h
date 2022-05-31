#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRootViewController : UITableViewController {
    IALGeneralManager *_manager;
    NSDate *_startTime;
    NSDate *_endTime;
}
@end

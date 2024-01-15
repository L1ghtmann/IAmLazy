#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRootViewController : UIViewController {
    IALGeneralManager *_manager;
    UIView *_mainView;
    UIStackView *_labelContainer;
    UIStackView *_itemContainer;
    NSDate *_startTime;
    NSDate *_endTime;
}
@end

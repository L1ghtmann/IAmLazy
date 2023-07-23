#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRootViewController : UIViewController {
    IALGeneralManager *_manager;
    UIView *_panelOneContainer;
    UIView *_panelTwoContainer;
    int _controlPanelState;
    UISegmentedControl *_configSwitch;
    NSDate *_startTime;
    NSDate *_endTime;
}
@end

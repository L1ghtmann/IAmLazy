#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRootViewController : UIViewController {
    IALGeneralManager *_manager;
    UIView *_mainView;
    NSDate *_startTime;
    NSDate *_endTime;
}
-(void)restoreFromBackup:(NSString *)backup;
-(void)popPostBackupWithInfo:(NSString *)info;
-(void)popPostRestore;
-(UIColor *)IALBlue;
-(UIColor *)IALYellow;
@end

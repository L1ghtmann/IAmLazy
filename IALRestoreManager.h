#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALRestoreManager : NSObject
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
@end

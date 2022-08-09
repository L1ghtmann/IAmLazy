#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALRestoreManager : NSObject {
    NSNotificationCenter *_notifCenter;
}
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)restoreFromBackup:(NSString *)backupName;
@end

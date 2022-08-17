#import <UIKit/UIKit.h>

@class IALRestoreManager, IALBackupManager;

@interface IALGeneralManager : NSObject {
    IALRestoreManager *_restoreManager;
    IALBackupManager *_backupManager;
}
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic) BOOL encounteredError;
+(instancetype)sharedManager;
-(void)makeBackupWithFilter:(BOOL)filter;
-(void)restoreFromBackup:(NSString *)backupName;
-(void)ensureBackupDirExists;
-(void)cleanupTmp;
-(void)updateAPT;
-(NSArray<NSString *> *)getBackups;
-(void)executeCommandAsRoot:(NSString *)cmd;
-(void)updateItemStatus:(CGFloat)status;
-(void)updateItemProgress:(CGFloat)status;
-(void)displayErrorWithMessage:(NSString *)msg;
@end

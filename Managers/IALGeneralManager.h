#import <UIKit/UIKit.h>

@class IALRestoreManager, IALBackupManager;

@interface IALGeneralManager : NSObject {
    IALRestoreManager *_restoreManager;
    IALBackupManager *_backupManager;
}
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic) BOOL encounteredError;
+(instancetype)sharedManager;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
-(void)ensureBackupDirExists;
-(void)cleanupTmp;
-(void)updateAPT;
-(NSArray<NSString *> *)getBackups;
-(void)executeCommandAsRoot:(NSString *)cmd;
-(void)displayErrorWithMessage:(NSString *)msg;
@end

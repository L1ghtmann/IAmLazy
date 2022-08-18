#import <UIKit/UIKit.h>

@class IALRestoreManager, IALBackupManager;

@interface IALGeneralManager : NSObject {
    IALRestoreManager *_restoreManager;
    IALBackupManager *_backupManager;
}
@property (nonatomic, retain) UIViewController *rootVC;
+(instancetype)sharedManager;
-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL))completed;
-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed;
-(void)ensureBackupDirExists;
-(void)cleanupTmp;
-(void)updateAPT;
-(NSArray<NSString *> *)getBackups;
-(void)executeCommandAsRoot:(NSString *)cmd;
-(void)updateItemStatus:(CGFloat)status;
-(void)updateItemProgress:(CGFloat)status;
-(void)displayErrorWithMessage:(NSString *)msg;
@end

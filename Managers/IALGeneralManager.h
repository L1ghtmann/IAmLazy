#import <UIKit/UIKit.h>

@class IALRestoreManager, IALBackupManager;

@interface IALGeneralManager : NSObject {
    IALRestoreManager *_restoreManager;
    IALBackupManager *_backupManager;
}
@property (nonatomic, retain) UIViewController *rootVC;
#if CLI
-(instancetype)sharedManagerForPurpose:(NSInteger)purpose;
#endif
+(instancetype)sharedManager;
-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL))completed;
-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed;
-(BOOL)ensureBackupDirExists;
-(BOOL)cleanupTmp;
-(BOOL)updateAPT;
-(NSArray<NSString *> *)getBackups;
-(BOOL)executeCommandAsRoot:(NSString *)cmd;
-(void)updateItemStatus:(CGFloat)status;
-(void)updateItemProgress:(CGFloat)status;
-(void)displayErrorWithMessage:(NSString *)msg;
@end

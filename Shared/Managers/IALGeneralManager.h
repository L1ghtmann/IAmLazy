#import <UIKit/UIKit.h>

@class IALRestoreManager, IALBackupManager;

typedef NS_ENUM(NSInteger, ItemType) {
    ItemTypeStatus,
    ItemTypeProgress
};

@interface IALGeneralManager : NSObject {
    IALRestoreManager *_restoreManager;
    IALBackupManager *_backupManager;
}
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic, retain) UIViewController *debugVC;
+(instancetype)sharedManager;
-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL, NSString *))completed;
-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed;
-(BOOL)ensureBackupDirExists;
-(BOOL)ensureUsableDpkgLock;
-(BOOL)cleanupTmp;
-(BOOL)updateAPT;
-(NSArray<NSString *> *)getBackups;
-(BOOL)executeCommandAsRoot:(NSString *)cmd;
-(void)updateItem:(NSInteger)item WithStatus:(CGFloat)status;
-(void)displayErrorWithMessage:(NSString *)msg;
@end

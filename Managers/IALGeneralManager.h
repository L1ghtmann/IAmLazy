#import <UIKit/UIKit.h>

@class IALRestoreManager;
@class IALBackupManager;

@interface IALGeneralManager : NSObject
@property (nonatomic, retain) IALRestoreManager *restoreManager;
@property (nonatomic, retain) IALBackupManager *backupManager;
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic) BOOL encounteredError;
+(instancetype)sharedInstance;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
-(void)cleanupTmp;
-(void)cleanupTargetList;
-(NSString *)getLatestBackup;
-(NSArray *)getBackups;
-(void)executeCommandAsRoot:(NSString *)cmd;
-(void)popErrorAlertWithReason:(NSString *)reason;
@end

#import <UIKit/UIKit.h>

@interface IAmLazyManager : NSObject
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSDate *endTime;
@property (nonatomic, retain) NSArray *allPackages;
@property (nonatomic, retain) NSArray *userPackages;
@property (nonatomic) CGFloat estimatedBackupSize;
@property (nonatomic) BOOL encounteredError;
+(instancetype)sharedInstance;
-(CGFloat)getSizeOfAllPackages;
-(NSArray *)getBackups;
-(int)getLatestBackup;
-(void)executeCommand:(NSString *)cmd;
-(NSString *)executeCommandWithOutput:(NSString *)cmd andWait:(BOOL)wait;
-(void)executeCommandAsRoot:(NSArray *)args;
-(void)makeTweakBackup;
-(NSArray *)getAllPackages;
-(NSArray *)getUserPackages;
-(void)gatherDebFiles;
-(void)buildDebs;
-(void)makeTarball;
-(void)verifyBackup;
-(NSString *)getDuration;
-(void)restoreFromBackup;
-(void)restoreFromBackup:(NSString *)backupName;
-(void)unpackArchive:(NSString *)backupName;
-(void)installDebs;
@end

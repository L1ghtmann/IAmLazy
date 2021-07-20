#import <UIKit/UIKit.h>

@interface IALManager : NSObject
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSArray *packages;
@property (nonatomic, retain) NSDate *endTime;
@property (nonatomic) BOOL encounteredError;
+(instancetype)sharedInstance;
-(void)makeTweakBackupWithFilter:(BOOL)filter;
-(NSArray *)getAllPackages;
-(NSArray *)getUserPackages;
-(void)gatherPackageFiles;
-(void)buildDebs;
-(void)makeTarballWithFilter:(BOOL)filter;
-(NSString *)getDuration;
-(void)restoreFromBackup:(NSString *)backupName;
-(void)unpackArchive:(NSString *)backupName;
-(void)installDebs;
-(NSArray *)getBackups;
-(void)executeCommand:(NSString *)cmd;
-(NSString *)executeCommandWithOutput:(NSString *)cmd andWait:(BOOL)wait;
-(void)executeCommandAsRoot:(NSArray *)args;
@end

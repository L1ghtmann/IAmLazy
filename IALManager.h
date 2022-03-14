#import <UIKit/UIKit.h>

@interface IALManager : NSObject
@property (nonatomic, retain) UIViewController *rootVC;
@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSArray *packages;
@property (nonatomic, retain) NSDate *endTime;
@property (nonatomic) BOOL encounteredError;
+(instancetype)sharedInstance;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(NSString *)getDuration;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
-(NSString *)getLatestBackup;
-(NSArray *)getBackups;
@end

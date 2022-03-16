#import <UIKit/UIKit.h>

@class IALGeneralManager;

@interface IALBackupManager : NSObject
@property (nonatomic, retain) IALGeneralManager *generalManager;
@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSArray *packages;
@property (nonatomic, retain) NSDate *endTime;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(NSString *)getDuration;
@end

#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALBackupManager : NSObject
@property (nonatomic, retain) IALGeneralManager *generalManager;
@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSArray<NSString *> *packages;
@property (nonatomic, retain) NSArray<NSString *> *controls;
@property (nonatomic, retain) NSDate *endTime;
-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter;
-(NSString *)getDuration;
@end

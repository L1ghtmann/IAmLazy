#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALRestoreManager : NSObject
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed;
@end

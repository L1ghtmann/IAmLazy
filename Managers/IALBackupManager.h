#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALBackupManager : NSObject {
    BOOL _filtered;
    NSNotificationCenter *_notifCenter;
    NSArray<NSString *> *_controlFiles;
    NSArray<NSString *> *_packages;
}
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)makeBackupWithFilter:(BOOL)filter;
@end

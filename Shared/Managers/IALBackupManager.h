#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALBackupManager : NSObject {
    NSArray<NSString *> *_controlFiles;
    NSArray<NSString *> *_packages;
}
@property (nonatomic) BOOL filtered;
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL))completed;
@end
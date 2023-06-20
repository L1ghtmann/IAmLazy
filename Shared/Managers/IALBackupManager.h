#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALBackupManager : NSObject {
    NSArray<NSString *> *_controlFiles;
    NSMutableArray<NSString *> *_packages;
    NSMutableArray<NSString *> *_skip;
}
@property (nonatomic) BOOL filtered;
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL, NSString *))completed;
@end

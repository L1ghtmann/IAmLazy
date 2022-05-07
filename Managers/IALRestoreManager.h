#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALRestoreManager : NSObject <NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>
@property (nonatomic, retain) IALGeneralManager *generalManager;
@property (nonatomic, retain) NSArray<NSURL *> *debURLS;
@property (nonatomic) int expectedDownloads;
@property (nonatomic) int actualDownloads;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
@end

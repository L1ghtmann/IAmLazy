#import <Foundation/Foundation.h>

@class IALGeneralManager;

@interface IALRestoreManager : NSObject <NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>  {
    int _expectedDownloads;
    int _actualDownloads;
}
@property (nonatomic, retain) IALGeneralManager *generalManager;
-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type;
@end

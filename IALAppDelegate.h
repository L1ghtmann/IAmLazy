#import <UIKit/UIKit.h>

@interface IALAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, strong) UINavigationController *rootViewController;
@property (nonatomic, strong) UINavigationController *backupsViewController;
@property (nonatomic, strong) UINavigationController *restoreViewController;
@end

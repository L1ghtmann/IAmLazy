#import <UIKit/UIKit.h>

@interface IALAppDelegate : UIResponder <UIApplicationDelegate> {
    UIWindow *_window;
    UITabBarController *_tabBarController;
    UINavigationController *_rootNavigationController;
    UINavigationController *_restoreNavigationController;
}
@property (nonatomic, strong) UINavigationController *backupsNavigationController;
@end

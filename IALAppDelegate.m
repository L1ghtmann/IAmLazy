//
//	IALAppDelegate.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "UI/IALBackupsViewController.h"
#import "UI/IALRestoreViewController.h"
#import "UI/IALNavigationController.h"
#import "UI/IALRootViewController.h"
#import "IALAppDelegate.h"

@implementation IALAppDelegate

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
	// controllers for each page
	_rootNavigationController = [[IALNavigationController alloc] initWithRootViewController:[[IALRootViewController alloc] init]];
	_backupsNavigationController = [[IALNavigationController alloc] initWithRootViewController:[[IALBackupsViewController alloc] init]];
	_restoreNavigationController = [[IALNavigationController alloc] initWithRootViewController:[[IALRestoreViewController alloc] init]];

	// the 'root' controller that controls which controller ^ is presented
	_tabBarController = [UITabBarController new];
	[_tabBarController setViewControllers:@[_rootNavigationController, _backupsNavigationController, _restoreNavigationController]];

	// key/root window
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[_window setRootViewController:_tabBarController];
	[_window makeKeyAndVisible];

	return YES;
}

@end

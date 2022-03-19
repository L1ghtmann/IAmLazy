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
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

	// controllers for each page
	_rootViewController = [[IALNavigationController alloc] initWithRootViewController:[[IALRootViewController alloc] init]];
	_backupsViewController = [[IALNavigationController alloc] initWithRootViewController:[[IALBackupsViewController alloc] init]];
	_restoreViewController = [[IALNavigationController alloc] initWithRootViewController:[[IALRestoreViewController alloc] init]];

	// the 'root' controller that controls which controller ^ is presented
	_tabBarController = [UITabBarController new];
	_tabBarController.viewControllers = @[_rootViewController, _backupsViewController, _restoreViewController];
	_window.rootViewController = _tabBarController;

	[_window makeKeyAndVisible];

	return YES;
}

@end

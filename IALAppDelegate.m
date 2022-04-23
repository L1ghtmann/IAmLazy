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
	[_tabBarController setViewControllers:@[_rootViewController, _backupsViewController, _restoreViewController]];
	[_window setRootViewController:_tabBarController];

	[_window makeKeyAndVisible];

	// check for rootless
	if([[NSFileManager defaultManager] isWritableFileAtPath:@"/"] == 1){
		UIAlertController *alert = [UIAlertController
							alertControllerWithTitle:@"IAmLazy"
							message:@"Note: your device is running a rootless jailbreak.\n\nThis version of IAmLazy does not support rootless jailbreaks.\n\nPlease use 'IAmLazy (Rootless)' instead."
							preferredStyle:UIAlertControllerStyleAlert];

		[_tabBarController presentViewController:alert animated:YES completion:nil];
	}

	return YES;
}

@end

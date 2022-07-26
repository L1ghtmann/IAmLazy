//
//	IALAppDelegate.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "UI/IALRootViewController.h"
#import "IALAppDelegate.h"

@implementation IALAppDelegate

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[_window setRootViewController:[[IALRootViewController alloc] init]];
	[_window makeKeyAndVisible];
	return YES;
}

@end

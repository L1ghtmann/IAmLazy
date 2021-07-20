#import "IALAppDelegate.h"
#import "IALRootViewController.h"

// Lightmann
// Made during covid
// IAmLazy

@implementation IALAppDelegate

-(void)applicationDidFinishLaunching:(UIApplication *)application{
	_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_rootViewController = [[UINavigationController alloc] initWithRootViewController:[[IALRootViewController alloc] init]];
	_window.rootViewController = _rootViewController;
	[_window makeKeyAndVisible];
}

@end

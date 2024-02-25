#import "UI/IALRootViewController.h"
#import "IALAppDelegate.h"
#import <Common.h>

@implementation IALAppDelegate

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[_window setRootViewController:[[IALRootViewController alloc] init]];
	[_window makeKeyAndVisible];

	// XinaA15 v1
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/var/Liy/xina"]){
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"IAmLazy"
									message:[NSString stringWithFormat:localize(@"Your current jailbreak is %@!"), @"XinaA15 (v1)"]
									preferredStyle:UIAlertControllerStyleAlert];
		[_window.rootViewController presentViewController:alert animated:YES completion:nil];
	}

	return YES;
}

@end

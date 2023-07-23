#import "UI/IALRootViewController.h"
#import "IALAppDelegate.h"

@implementation IALAppDelegate

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[_window setRootViewController:[[IALRootViewController alloc] init]];
	[_window makeKeyAndVisible];

	BOOL dir = NO;
	BOOL jb = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/Liy/xina" isDirectory:&dir];
	if(jb && dir){
		UIAlertController *alert = [UIAlertController
									alertControllerWithTitle:@"Note"
									message:@"XinaA15 is not currently supported.\n\nIf you'd like to see support, please let me know."
									preferredStyle:UIAlertControllerStyleAlert];
		[_window.rootViewController presentViewController:alert animated:YES completion:nil];
	}

	return YES;
}

@end

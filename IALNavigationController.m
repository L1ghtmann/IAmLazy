//
//	IALNavigationController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALNavigationController.h"

@implementation IALNavigationController

#pragma mark Setup

-(instancetype)initWithRootViewController:(UIViewController *)controller{
	self = [super initWithRootViewController:controller];

	if(self){
		// setup top nav bar
		[controller.navigationItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon40x40@2x-clear"]]];

		UIBarButtonItem *srcItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(openSrc)];
		[controller.navigationItem setLeftBarButtonItem:srcItem];

		UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(popInfo)];
		[controller.navigationItem setRightBarButtonItem:infoItem];
	}

	return self;
}

#pragma mark Popups

-(void)openSrc{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"URL Open Request"
								message:@"IAmLazy.app is requesting to open 'https://github.com/L1ghtmann/IAmLazy'\n\nWould you like to proceed?"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *yes = [UIAlertAction
							actionWithTitle:@"Yes"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"] options:@{} completionHandler:nil];
							}];

	UIAlertAction *no = [UIAlertAction
							actionWithTitle:@"No"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:yes];
	[alert addAction:no];

	[self presentViewController:alert animated:YES completion:nil];
}

-(void)popInfo{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"General Info"
								message:@"IAmLazy.app\nVersion: 2.0.0\n\nMade by Lightmann"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction * action) {
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:okay];

	[self presentViewController:alert animated:YES completion:nil];
}

@end

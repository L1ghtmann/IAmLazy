//
//	IALNavigationController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <SafariServices/SFSafariViewController.h>
#import "IALNavigationController.h"

@implementation IALNavigationController

#pragma mark Setup

-(instancetype)initWithRootViewController:(UIViewController *)controller{
	self = [super initWithRootViewController:controller];

	if(self){
		// setup top nav bar
		[controller.navigationItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Assets/Clear-Icon-40"]]];

		UIImage *infoImg = [UIImage systemImageNamed:@"info.circle.fill"];
		_infoItem = [[UIBarButtonItem alloc] initWithImage:infoImg style:UIBarButtonItemStylePlain target:self action:@selector(popInfo)];
		[controller.navigationItem setRightBarButtonItem:_infoItem];

		// scale GitHubMark image (https://stackoverflow.com/a/8224161)
		UIImage *githubMark = [UIImage imageNamed:@"Assets/GitHub-Mark-64px"];
		CGFloat scaleFactor = ((infoImg.size.width + 4)/githubMark.size.width);
		CGFloat newHeight = (githubMark.size.height * scaleFactor);
		CGFloat newWidth = (githubMark.size.width * scaleFactor);

		UIGraphicsBeginImageContextWithOptions(CGSizeMake(newWidth, newHeight), NO, 0);
		[githubMark drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
		UIImage *srcImg = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		_srcItem = [[UIBarButtonItem alloc] initWithImage:srcImg style:UIBarButtonItemStylePlain target:self action:@selector(openSrc)];
		[controller.navigationItem setLeftBarButtonItem:_srcItem];
	}

	return self;
}

#pragma mark Popups

-(void)openSrc{
	NSURL *url = [NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"];
	SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
	[self presentViewController:safariViewController animated:YES completion:nil];
}

-(void)popInfo{
	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"General Info"
								message:@"IAmLazy.app\nVersion: 2.0.0\n\nMade by Lightmann"
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[self dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:okay];

	[self presentViewController:alert animated:YES completion:nil];
}

@end

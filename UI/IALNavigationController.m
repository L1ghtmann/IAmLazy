//
//	IALNavigationController.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALNavigationController.h"
#import "../IALAppDelegate.h"

@implementation IALNavigationController

#pragma mark Setup

-(instancetype)initWithRootViewController:(UIViewController *)controller{
	self = [super initWithRootViewController:controller];

	if(self){
		// setup top nav bar
		[controller.navigationItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Assets/Clear-Icon-40"]]];

		UIImage *githubMark = [UIImage imageNamed:@"Assets/GitHub-Mark-64px"];
		githubMark = [UIImage imageWithCGImage:[githubMark CGImage] scale:([[UIScreen mainScreen] scale] * 1.45) orientation:[githubMark imageOrientation]];

		_srcItem = [[UIBarButtonItem alloc] initWithImage:githubMark style:UIBarButtonItemStylePlain target:self action:@selector(openSrc)];
		[controller.navigationItem setLeftBarButtonItem:_srcItem];

		_infoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(popInfo)];
		[controller.navigationItem setRightBarButtonItem:_infoItem];
	}

	return self;
}

#pragma mark Popups

-(void)openSrc{
	// build web view
	_webViewConfiguration = [[WKWebViewConfiguration alloc] init];
	_webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:_webViewConfiguration];
	[_webView setNavigationDelegate:self];

	// create back and close nav bar buttons for use with webview
	UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.left"] style:UIBarButtonItemStylePlain target:_webView action:@selector(goBack)];
	UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeWebView)];
	[self.visibleViewController.navigationItem setLeftBarButtonItems:@[backItem, closeItem]];

	// hide right nav bar button
	[self.visibleViewController.navigationItem.rightBarButtonItem setTintColor:[UIColor clearColor]];

	// present the webview
	NSURL *url = [NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"];
	[_webView loadRequest:[NSURLRequest requestWithURL:url]];
	[self.visibleViewController.view addSubview:_webView];

	// hide tabbar
	IALAppDelegate *delegate = (IALAppDelegate*)[[UIApplication sharedApplication] delegate];
	[delegate.tabBarController.tabBar setAlpha:0];
}

-(void)closeWebView{
	// dispose of webview
	[UIView animateWithDuration:0.2
			animations:^{
				[_webView setAlpha:0];
			}
	 		completion:^(BOOL finished){
				[_webView removeFromSuperview];
				_webViewConfiguration = nil;
				_webView = nil;
			}];

	// reset left nav bar buttons (set to just the src button)
	[self.visibleViewController.navigationItem setLeftBarButtonItems:@[_srcItem]];

	// unhide right nav bar button
	[self.visibleViewController.navigationItem.rightBarButtonItem setTintColor:nil];

	// unhide tabbar
	IALAppDelegate *delegate = (IALAppDelegate*)[[UIApplication sharedApplication] delegate];
	[UIView animateWithDuration:0.2 animations:^{
		[delegate.tabBarController.tabBar setAlpha:1];
	}];
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

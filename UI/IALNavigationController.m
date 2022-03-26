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

		UIImage *githubMark = [UIImage imageNamed:@"GitHub-Mark-64px"];
		githubMark = [UIImage imageWithCGImage:[githubMark CGImage] scale:[[UIScreen mainScreen] scale]*1.45 orientation:[githubMark imageOrientation]];
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
	NSURL *url = [NSURL URLWithString:@"https://github.com/L1ghtmann/IAmLazy"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url];

	// create back and close nav bar buttons for use with webview
	UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.left"] style:UIBarButtonItemStylePlain target:_webView action:@selector(goBack)];
	UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeWebView)];
	[self.visibleViewController.navigationItem setLeftBarButtonItems:@[backItem, closeItem]];

	// hide right nav bar button
	[self.visibleViewController.navigationItem.rightBarButtonItem setTintColor:[UIColor clearColor]];

	// present the webview
	[_webView loadRequest:request];
	[self.visibleViewController.view addSubview:_webView];
}

-(void)closeWebView{
	// dispose of webview
	[UIView animateWithDuration:0.2
			animations:^{[_webView setAlpha:0];}
	 		completion:^(BOOL finished){
				[_webView removeFromSuperview];
			}];
	_webView = nil;
	_webViewConfiguration = nil;

	// reset left nav bar buttons (set to just the src button)
	[self.visibleViewController.navigationItem setLeftBarButtonItems:@[_srcItem]];

	// unhide right nav bar button
	[self.visibleViewController.navigationItem.rightBarButtonItem setTintColor:nil];
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

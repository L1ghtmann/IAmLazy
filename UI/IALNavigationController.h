#import <WebKit/WKWebViewConfiguration.h>
#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKWebView.h>
#import <UIKit/UIKit.h>

@interface IALNavigationController : UINavigationController <WKNavigationDelegate>
@property (nonatomic, retain) UIBarButtonItem *srcItem;
@property (nonatomic, retain) UIBarButtonItem *infoItem;
@property (nonatomic, retain) WKWebViewConfiguration *webViewConfiguration;
@property (nonatomic, retain) WKWebView *webView;
@end

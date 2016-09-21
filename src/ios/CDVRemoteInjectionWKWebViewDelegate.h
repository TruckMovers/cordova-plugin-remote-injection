#import <WebKit/WebKit.h>
#import "CDVRemoteInjection.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

@interface CDVRemoteInjectionWKWebViewNavigationDelegate: WrappedDelegateProxy <WKNavigationDelegate>
@end

@interface CDVRemoteInjectionWKWebViewDelegate: CDVRemoteInjectionWebViewBaseDelegate <CDVRemoteInjectionWebViewDelegate>
@property (readwrite, weak) CDVRemoteInjectionPlugin *plugin;
@end

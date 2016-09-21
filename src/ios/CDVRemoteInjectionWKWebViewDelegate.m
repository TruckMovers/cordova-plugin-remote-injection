#import "CDVRemoteInjectionWKWebViewDelegate.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

#import <Foundation/Foundation.h>

#define kCDVRemoteInjectionWKWebViewDidFinishLoad @"CDVRemoteInjectionWKWebViewDidFinishLoad"

@implementation CDVRemoteInjectionWKWebViewNavigationDelegate
@dynamic wrappedDelegate;

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionWKWebViewDidFinishLoad object:webView]];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [self.wrappedDelegate webView:webView didFinishNavigation:navigation];
    }
}
@end

@implementation CDVRemoteInjectionWKWebViewDelegate
{
    CDVRemoteInjectionWKWebViewNavigationDelegate *ourDelegate;
}
- (id) initWithPlugin:(CDVRemoteInjectionPlugin *) injectionPlugin
{
    return [super initWithPlugin:injectionPlugin];
}

- (void)initializeDelegate:(CDVRemoteInjectionPlugin*)plugin
{
    self.plugin = plugin;
    
    // Hook to inject cordova into the page.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidFinishLoad:)
                                                 name:kCDVRemoteInjectionWKWebViewDidFinishLoad
                                               object:nil];
    
    // Wrap the current delegate with our own so we can hook into web view events.
    WKWebView *webView = [plugin findWebView];
    ourDelegate = [[CDVRemoteInjectionWKWebViewNavigationDelegate alloc] init];
    ourDelegate.wrappedDelegate = [webView navigationDelegate];
    [webView setNavigationDelegate:ourDelegate];
}

/*
 After page load inject cordova and its plugins.
 */
- (void) webViewDidFinishLoad:(NSNotification*)notification
{
    // TODO
    //[self cancelRequestTimer];
    WKWebView *webView = notification.object;
    NSString *scheme = webView.URL.scheme;

    if ([self isSupportedURLScheme:scheme]) {
        [webView evaluateJavaScript:[self buildInjectionJS] completionHandler:^(id id, NSError *error){
            if (error) {
                // Nothing to do here other than log the error.
                NSLog(@"Error when injecting javascript into WKWebView: '%@'.", error);
            }
        }];
    }
}
@end

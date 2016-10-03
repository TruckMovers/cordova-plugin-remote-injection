//
//  CDVRemoteInjection.m
//

#import <Foundation/Foundation.h>

#import "CDVRemoteInjectionUIWebViewDelegate.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"


@implementation CDVRemoteInjectionUIWebViewNotificationDelegate
@dynamic wrappedDelegate;

- (void)webViewDidStartLoad:(UIWebView*)webView
{
    [self.webViewDelegate onWebViewDidStartLoad];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.wrappedDelegate webViewDidStartLoad:webView];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.webViewDelegate onWebViewDidFinishLoad:webView];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [self.wrappedDelegate webViewDidFinishLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [self.wrappedDelegate webView:webView didFailLoadWithError:error];
    }
    
    [self.webViewDelegate onWebViewFailLoadWithError:error];
}
@end

@implementation CDVRemoteInjectionUIWebViewDelegate
{
    CDVRemoteInjectionUIWebViewNotificationDelegate *notificationDelegate;
}

- (void)initializeDelegate:(CDVRemoteInjectionPlugin *)plugin
{
    self.plugin = plugin;

    // Wrap the current delegate with our own so we can hook into web view events.
    UIWebView *uiWebView = [plugin findWebView];
    notificationDelegate = [[CDVRemoteInjectionUIWebViewNotificationDelegate alloc] init];
    notificationDelegate.wrappedDelegate = [uiWebView delegate];
    notificationDelegate.webViewDelegate = self;
    [uiWebView setDelegate:notificationDelegate];
}

-(void) onWebViewDidStartLoad
{
    [super webViewRequestStart];
}

/*
 * After page load inject cordova and its plugins.
 */
- (void) onWebViewDidFinishLoad:(UIWebView *)webView
{
    // Cancel the slow request timer.
    [self cancelRequestTimer];
 
    // Inject cordova into the page.
    NSString *scheme = webView.request.URL.scheme;
 
    if ([self isSupportedURLScheme:scheme]){
        [webView stringByEvaluatingJavaScriptFromString:[self buildInjectionJS]];
    }
}

// Handles notifications from the webview delegate whenever a page load fails.
- (void) onWebViewFailLoadWithError:(NSError *)error
{
    [self loadPageFailure:error];
}

- (BOOL) isLoading
{
    UIWebView *uiWebView = [self.plugin findWebView];
    return uiWebView.loading;
}

- (void) retryCurrentRequest
{
    UIWebView *webView = [self.plugin findWebView];
    
    [webView stopLoading];
    [webView reload];
}

@end

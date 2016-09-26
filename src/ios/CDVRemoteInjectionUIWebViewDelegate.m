//
//  CDVRemoteInjection.m
//

#import <Foundation/Foundation.h>

#import "CDVRemoteInjectionUIWebViewDelegate.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

#define kCDVRemoteInjectionUIWebViewDidStartLoad @"CDVRemoteInjectionUIWebViewDidStartLoad"
#define kCDVRemoteInjectionUIWebViewDidFinishLoad @"CDVRemoteInjectionUIWebViewDidFinishLoad"
#define kCDVRemoteInjectionUIWebViewDidFailLoadWithError @"CDVRemoteInjectionUIWebViewDidFailLoadWithError"

@implementation CDVRemoteInjectionUIWebViewNotificationDelegate
@dynamic wrappedDelegate;

- (void)webViewDidStartLoad:(UIWebView*)webView
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionUIWebViewDidStartLoad object:webView]];

    if ([self.wrappedDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.wrappedDelegate webViewDidStartLoad: webView];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionUIWebViewDidFinishLoad object:webView]];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [self.wrappedDelegate webViewDidFinishLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [self.wrappedDelegate webView:webView didFailLoadWithError:error];
    }
    
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionUIWebViewDidFailLoadWithError object:error]];
}
@end

@implementation CDVRemoteInjectionUIWebViewDelegate
{
    CDVRemoteInjectionUIWebViewNotificationDelegate *notificationDelegate;
}

- (void)initializeDelegate:(CDVRemoteInjectionPlugin *)plugin
{
    self.plugin = plugin;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidStartLoad:)
                                                 name:kCDVRemoteInjectionUIWebViewDidStartLoad
                                               object:nil];
    
    // Hook to inject cordova into the page.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidFinishLoad:)
                                                 name:kCDVRemoteInjectionUIWebViewDidFinishLoad
                                               object:nil];
    
    // Hook to respond to page load failures.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didWebViewFailLoadWithError:)
                                                 name:kCDVRemoteInjectionUIWebViewDidFailLoadWithError
                                               object:nil];

    // Wrap the current delegate with our own so we can hook into web view events.
    UIWebView *uiWebView = [plugin findWebView];
    notificationDelegate = [[CDVRemoteInjectionUIWebViewNotificationDelegate alloc] init];
    notificationDelegate.wrappedDelegate = [uiWebView delegate];
    [uiWebView setDelegate:notificationDelegate];
}

-(void) webViewDidStartLoad:(NSNotification*)notification
{
    [super webViewRequestStart];
}

/*
 * After page load inject cordova and its plugins.
 */
- (void) webViewDidFinishLoad:(NSNotification*)notification
{
    // Cancel the slow request timer.
    [self cancelRequestTimer];
 
    // Inject cordova into the page.
    UIWebView *webView = notification.object;
    NSString *scheme = webView.request.URL.scheme;
 
    if ([self isSupportedURLScheme:scheme]){
        [webView stringByEvaluatingJavaScriptFromString:[self buildInjectionJS]];
    }
}

// Handles notifications from the webview delegate whenever a page load fails.
- (void)didWebViewFailLoadWithError:(NSNotification*)notification
{
    [self loadPageFailure];
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

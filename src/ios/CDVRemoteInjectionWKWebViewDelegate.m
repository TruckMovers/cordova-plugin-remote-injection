#import "CDVRemoteInjectionWKWebViewDelegate.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

#import <Foundation/Foundation.h>

#define kDidFinishLoad @"DidFinishLoad"
#define kDidStartProvisionNavigation @"DidStartProvisionNavigation"
#define kDidCommitNavigation @"DidCommitNavigation"
#define KDidFailNavigation @"DidFailNavigation"
#define KDidFailProvisionalNavigation @"DidFailProvisionalNavigation"

@implementation CDVRemoteInjectionWKWebViewNavigationDelegate
@dynamic wrappedDelegate;

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kDidFinishLoad object:webView]];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [self.wrappedDelegate webView:webView didFinishNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kDidStartProvisionNavigation object:webView]];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [self.wrappedDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

/*
 * Invoked when a page cannot be found.
 */
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:KDidFailProvisionalNavigation object:webView]];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [self.wrappedDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

@end

@implementation CDVRemoteInjectionWKWebViewDelegate
{
    CDVRemoteInjectionWKWebViewNavigationDelegate *ourDelegate;
}

- (void)initializeDelegate:(CDVRemoteInjectionPlugin *)plugin
{
    self.plugin = plugin;
    
    // Hook to inject cordova into the page.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWebViewDidFinishLoad:)
                                                 name:kDidFinishLoad
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWebViewDidStartProvisionalNavigation:)
                                                 name:kDidStartProvisionNavigation
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWebViewDidFailProvisionalNavigation:)
                                                 name:KDidFailProvisionalNavigation
                                               object:nil];
    
    //Wrap the current delegate with our own so we can hook into web view events.
    WKWebView *webView = [plugin findWebView];
    ourDelegate = [[CDVRemoteInjectionWKWebViewNavigationDelegate alloc] init];
    ourDelegate.wrappedDelegate = [webView navigationDelegate];
    [webView setNavigationDelegate:ourDelegate];
}

/*
 After page load inject cordova and its plugins.
 */
- (void) onWebViewDidFinishLoad:(NSNotification*)notification
{
    [self cancelRequestTimer];
    
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

/*
 * Page load request has been made.
 */
- (void) onWebViewDidStartProvisionalNavigation:(NSNotification *)notification
{
    [self webViewRequestStart];
}

- (void) onWebViewDidFailProvisionalNavigation: (NSNotification *)notification
{
    [self loadPageFailure];
}

/*
 * Returns true if the webView is loading a request.
 */
-(BOOL) isLoading
{
    WKWebView *webView = [self.plugin findWebView];
    return webView.loading;
}

/*
 * Inovked when the user wants to retry the current request.
 */
-(void) retryCurrentRequest
{
    WKWebView *webView = [self.plugin findWebView];
    
    [webView stopLoading];
    [webView reload];
}

@end

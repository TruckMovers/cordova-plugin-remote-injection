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
    [self.webViewDelegate onWebViewDidFinishLoad:webView];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [self.wrappedDelegate webView:webView didFinishNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [self.webViewDelegate onWebViewDidStartProvisionalNavigation];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [self.wrappedDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;
{
    [self.webViewDelegate onWebViewDidFailNavigation:error];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [self.wrappedDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error;
{
    [self.webViewDelegate onWebViewDidFailNavigation:error];
    
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [self.wrappedDelegate webView:webView didFailNavigation:navigation withError:error];
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
    
    //Wrap the current delegate with our own so we can hook into web view events.
    WKWebView *webView = [plugin findWebView];
    ourDelegate = [[CDVRemoteInjectionWKWebViewNavigationDelegate alloc] init];
    ourDelegate.wrappedDelegate = [webView navigationDelegate];
    ourDelegate.webViewDelegate = self;
    
    [webView setNavigationDelegate:ourDelegate];
}

/*
 After page load inject cordova and its plugins.
 */
- (void) onWebViewDidFinishLoad:(WKWebView *)webView;
{
    [self cancelRequestTimer];
    
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

- (void) onWebViewDidStartProvisionalNavigation
{
    [self webViewRequestStart];
}

- (void) onWebViewDidFailNavigation:(NSError *)error
{
    [self loadPageFailure:error];
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

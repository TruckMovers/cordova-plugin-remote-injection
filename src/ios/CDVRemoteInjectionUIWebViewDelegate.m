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
                                                 name:kCDVRemoteInjectionUIWebViewDidFinishLoad
                                               object:nil];
    
    // Wrap the current delegate with our own so we can hook into web view events.
    UIWebView *uiWebView = [plugin findWebView];
    notificationDelegate = [[CDVRemoteInjectionUIWebViewNotificationDelegate alloc] init];
    notificationDelegate.wrappedDelegate = [uiWebView delegate];
    [uiWebView setDelegate:notificationDelegate];
}

/*
 After page load inject cordova and its plugins.
 */
 - (void) webViewDidFinishLoad:(NSNotification*)notification
 {
     // TODO
     //[self cancelRequestTimer];
 
     UIWebView *webView = notification.object;
     NSString *scheme = webView.request.URL.scheme;
 
     if ([self isSupportedURLScheme:scheme]){
         [webView stringByEvaluatingJavaScriptFromString:[self buildInjectionJS]];
     }
 }
@end

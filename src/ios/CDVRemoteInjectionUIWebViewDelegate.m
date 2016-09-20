//
//  CDVRemoteInjection.m
//

#import "CDVRemoteInjectionUIWebViewDelegate.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

#import <Foundation/Foundation.h>

@implementation CDVRemoteInjectionUIWebViewNotificationDelegate

- (void)webViewDidStartLoad:(UIWebView*)webView
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionUIWebViewDidStartLoad object:webView]];

    if ([self.wrappedDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.wrappedDelegate webViewDidStartLoad: webView];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([self.wrappedDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        return [self.wrappedDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    return true;
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

- (void) injectCordova;
{
    NSArray *jsPaths = [self jsPathsToInject];
    
    NSString *path;
    for (path in jsPaths) {
        if ([path rangeOfString:@"cordova-plugin-wkwebview-engine"].location != NSNotFound) {
            // Nasty hack to not include the wkwebview plugin JS.
            continue;
        }
        
        NSString *jsFilePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
        
        NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
        NSString *js = [NSString stringWithContentsOfFile:jsURL.path encoding:NSUTF8StringEncoding error:nil];
        
        NSLog(@"Injecting JS file into remote site: %@", jsURL.path);
        UIWebView *uiWebView = [self.plugin findWebView];
        [uiWebView stringByEvaluatingJavaScriptFromString:js];
    }
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
 
     if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
         [self injectCordova];
     } else {
         NSLog(@"Unsupported scheme for cordova injection: %@.  Skipping...", scheme);
     }
 }

/*
- (void)retry:(id)webView
{
    UIWebView *view = webView;
    
    [view stopLoading];
    [view reload];
}*/

@end

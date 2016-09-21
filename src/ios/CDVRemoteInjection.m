//
//  CDVRemoteInjection.m
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "CDVRemoteInjection.h"
#import "CDVRemoteInjectionUIWebViewDelegate.h"
#import "CDVRemoteInjectionWKWebViewDelegate.h"

@implementation CDVRemoteInjectionPlugin {
    /*
     Last time a request was made to load the web view.  Can be NULL.
     */
    NSDate *lastRequestTime;
    
    /*
     True if the user forced a reload.
     */
    BOOL forcedReload;
    
    /*
     Reference to the currently displayed alert view.  Can be NULL.
     */
    UIAlertView *alertView;
    
    /*
     * Delegate instance for the type of webView the containing app is using.
     */
    id <CDVRemoteInjectionWebViewDelegate> webViewDelegate;
}

/*
 Returns the current webView.  There's no guarantee as to the type of the 
 webView at this point.
 */
- (id) findWebView
{
#ifdef __CORDOVA_4_0_0
    return [[self webViewEngine] engineWebView];
#else
    return [self webView];
#endif
}

- (void) pluginInitialize
{
    [super pluginInitialize];
    
    // Read configuration for JS to inject before injecting cordova.
    NSString *value = [self settingForKey:@"CRIInjectFirstFiles"];
    if (value != NULL) {
        // Multiple files can be specified in the value, split the string on ",".
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        for (id path in [value componentsSeparatedByString:@","]) {
            [paths addObject: [self trim: path]];
        }
        _injectFirstFiles = paths;
    } else {
        _injectFirstFiles = [[NSArray alloc] init];
    }
    
    value = [self settingForKey:@"CRIPageLoadPromptInterval"];
    if (value != NULL) {
        _promptInterval = [value integerValue];
    } else {
        // Defaulting to a safe value.  For most apps this will be
        // too long.  The developer should set the pref to something more
        // acceptable.  Off by default in this case doesn't seem acceptable.
        // If wanting to turn off set the value to 0 in the pref.
        _promptInterval = 10;
    }

    id webView = [self findWebView];
    if ([webView isKindOfClass:[UIWebView class]]) {
        NSLog(@"Found UIWebView");
        webViewDelegate = [[CDVRemoteInjectionUIWebViewDelegate alloc] init];
        [webViewDelegate initializeDelegate:self];
        
        return;
    } else if ([webView isKindOfClass:[WKWebView class]]) {
        NSLog(@"Found WKWebView");
        webViewDelegate = [[CDVRemoteInjectionWKWebViewDelegate alloc] init];
        [webViewDelegate initializeDelegate:self];
        
        return;
    } else {
        NSLog(@"Not a supported web view implementation");
    }
}

/*
 Holy crap these APIs are verbose...
 */
- (NSString *) trim:(NSString *)s
{
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

/*
 Prompts the user providing them a choice to retry the latest request or wait.
 */
-(void) displayRetryPromptWithMessage:(NSString*)message withCancelText:(NSString *)cancelText
{
    alertView = [[UIAlertView alloc] initWithTitle:@"Connection Error"
                                                     message:message
                                                    delegate:self
                                           cancelButtonTitle:cancelText
                                           otherButtonTitles:nil];
    [alertView addButtonWithTitle:@"Retry"];
    [alertView show];
}

/*
 Invoked as callback from UIAlertView when prompting the user about connection issues.
 */
- (void)alertView:(UIAlertView *)view didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    alertView = NULL;
    
    if(buttonIndex == 1)
    {
        id webView = [self findWebView];
        
        forcedReload = YES; // Allows us to keep track of the fact that an error may be raised
        // by the webView as a result of attempting to load a page before the previous request finished.
        
        //[webViewDelegate retry:webView];
    }
    
    if (buttonIndex == 0 || buttonIndex == 1) {
        // In either the case that the user says to wait or retry we always want to reset the timer so that they're
        // prompted if the request has not completed.  This provides the user a way to get out of a blank screen
        // on start up.
        [self startRequestTimer];
    }
}

/*
 Determines if the user should be prompted because of a long running request.  Displays the prompt.
 */
-(void) loadProgressCheck:(id)requestTime
{
    UIWebView* webView = [self findWebView];
    
    if (lastRequestTime != NULL && webView.loading && [(NSDate *)requestTime isEqualToDate:lastRequestTime]) {
        [self displayRetryPromptWithMessage:@"The server is taking longer than expected to respond." withCancelText:@"Wait"];
    }
}

/*
 Begins a timer to track the progress of a request.
 */
-(void) startRequestTimer
{
    if (_promptInterval > 0) {
        [self cancelRequestTimer];
        lastRequestTime = [NSDate date];
    
        // Schedule progress check.
        [self performSelector:@selector(loadProgressCheck:) withObject:lastRequestTime afterDelay:_promptInterval];
    }
}

/*
 Resets the request timer state.  Hides the alert view if it is displayed.
 */
-(void) cancelRequestTimer
{
    if (alertView != NULL && alertView.visible == YES) {
        // Dismiss the alert view.  The assumption is the page finished loading while the view was displayed.
        [alertView dismissWithClickedButtonIndex:-1 animated:YES];
        alertView = NULL;
    }
    
    if (lastRequestTime != NULL) {
        [NSObject cancelPreviousPerformRequestsWithTarget:(id)self selector:@selector(loadProgressCheck:) object:lastRequestTime];
    }
    lastRequestTime = NULL;
}

-(void) webViewDidStartLoad:(NSNotification*)notification
{
    forcedReload = NO;
    [self startRequestTimer];
}

/*
 After page load inject cordova and its plugins.

- (void) webViewDidFinishLoad:(NSNotification*)notification
{
    [self cancelRequestTimer];
    
    UIWebView *webView = notification.object;
    NSString *scheme = webView.request.URL.scheme;
    
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        [self injectCordova];
    } else {
        NSLog(@"Unsupported scheme for cordova injection: %@.  Skipping...", scheme);
    }
} */

// Handles notifications from the webview delegate whenever a page load fails.
- (void)didWebViewFailLoadWithError:(NSNotification*)notification
{
    if (forcedReload == NO) {
        [self displayRetryPromptWithMessage:@"Unable to contact the site." withCancelText:@"Close"];
    }
}

- (id)settingForKey:(NSString*)key
{
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

@end

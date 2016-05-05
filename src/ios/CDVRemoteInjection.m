//
//  CDVRemoteInjection.m
//

#import "CDVRemoteInjection.h"
#import <Foundation/Foundation.h>
#import <Cordova/CDVAvailability.h>

@implementation CDVRemoteInjectionWebViewNotificationDelegate

- (void)webViewDidStartLoad:(UIWebView*)webView
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionWebViewDidStartLoad object:webView]];
    
    [self.wrappedDelegate webViewDidStartLoad: webView];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return [self.wrappedDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionWebViewDidFinishLoad object:webView]];
    
    [self.wrappedDelegate webViewDidFinishLoad:webView];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self.wrappedDelegate webView:webView didFailLoadWithError:error];
    
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVRemoteInjectionWebViewDidFailLoadWithError object:error]];
}

@end

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
     From CRIPageLoadPromptInterval preference.  Wait period in seconds before prompting the
     end user about a slow request.  Default is 10 which feels safe.  Off by default
     doesn't seem correct.  To disable the dialog completely set to 0.
     */
    NSInteger promptInterval;
}

- (UIWebView *) findWebView
{
    UIWebView *webView;
#ifdef __CORDOVA_4_0_0
    UIView *view = [[self webViewEngine] engineWebView];
    
    if ([view isKindOfClass:[UIWebView class]]) {
        webView = (UIWebView *) view;
    }
#else
    webView = [self webView];
#endif
    
    return webView;
}
- (void) pluginInitialize
{
    [super pluginInitialize];
    
    // Hook to inject cordova into the page.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidStartLoad:)
                                                 name:kCDVRemoteInjectionWebViewDidStartLoad
                                               object:nil];
    
    // Hook to inject cordova into the page.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidFinishLoad:)
                                                 name:kCDVRemoteInjectionWebViewDidFinishLoad
                                               object:nil];
    
    // Hook to respond to page load failures.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didWebViewFailLoadWithError:)
                                                 name:kCDVRemoteInjectionWebViewDidFailLoadWithError
                                               object:nil];
    
    UIWebView *webView = [self findWebView];
    
    // Wrap the current delegate with our own so we can hook into web view events.
    notificationDelegate = [[CDVRemoteInjectionWebViewNotificationDelegate alloc] init];
    notificationDelegate.wrappedDelegate = [webView delegate];
    [webView setDelegate:notificationDelegate];
    
    // Read configuration to read in files to inject first.
    NSString *value = [self settingForKey:@"CRIInjectFirstFiles"];
    if (value != NULL) {
        // Multiple files can be specified in the value, split the string on ",".
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        for (id path in [value componentsSeparatedByString:@","]) {
            [paths addObject: [self trim: path]];
        }
        
        [self setPreInjectionJSFiles: paths];
    } else {
        [self setPreInjectionJSFiles: [[NSArray alloc] init]];
    }
    
    value = [self settingForKey:@"CRIPageLoadPromptInterval"];
    if (value != NULL) {
        promptInterval = [value integerValue];
    } else {
        // Defaulting to a safe value.  For most apps this will be
        // to long.  The developer should set the pref to something more
        // acceptable.  Off by default in this case doesn't seem acceptable.
        // If wanting to turn off set the value to 0 in the pref.
        promptInterval = 10;
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
        UIWebView *webView = [self findWebView];
        
        forcedReload = YES; // Allows us to keep track of the fact that an error may be raised
        // by the webView as a result of attempting to load a page before the previous request finished.
        
        [webView stopLoading];
        [webView reload];
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
    if (promptInterval > 0) {
        [self cancelRequestTimer];
        lastRequestTime = [NSDate date];
    
        // Schedule progress check.
        [self performSelector:@selector(loadProgressCheck:) withObject:lastRequestTime afterDelay:promptInterval];
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
 */
- (void) webViewDidFinishLoad:(NSNotification*)notification
{
    [self cancelRequestTimer];
    
    UIWebView *webView = notification.object;
    NSString *scheme = webView.request.URL.scheme;
    
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        [self injectCordova: webView];
    } else {
        NSLog(@"Unsupported scheme for cordova injection: %@.  Skipping...", scheme);
    }
}

- (void) injectCordova:(UIWebView*)webView
{
    NSArray *jsPaths = [self jsPathsToInject];
    
    NSString *path;
    for (path in jsPaths) {
        NSString *jsFilePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
        
        NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
        NSString *js = [NSString stringWithContentsOfFile:jsURL.path encoding:NSUTF8StringEncoding error:nil];
        
        NSLog(@"Injecting JS file into remote site: %@", jsURL.path);
        [webView stringByEvaluatingJavaScriptFromString:js];
    }
}

- (NSArray *) jsPathsToInject
{
    // Array of paths that represent JS files to inject into the WebView.  Order is important.
    NSMutableArray *jsPaths = [NSMutableArray new];
    
    // Pre injection files.
    for (id path in [self preInjectionJSFiles]) {
        [jsPaths addObject: path];
    }
    
    [jsPaths addObject:@"www/cordova.js"];
    
    // We load the plugin code manually rather than allow cordova to load them (via
    // cordova_plugins.js).  The reason for this is the WebView will attempt to load the
    // file in the origin of the page (e.g. https://example.com/plugins/plugin/plugin.js).
    // By loading them first cordova will skip the loading process altogether.
    NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[[NSBundle mainBundle] pathForResource:@"www/plugins" ofType:nil]];
    
    NSString *path;
    while (path = [directoryEnumerator nextObject])
    {
        if ([path hasSuffix: @".js"]) {
            [jsPaths addObject: [NSString stringWithFormat:@"%@/%@", @"www/plugins", path]];
        }
    }
    // Initialize cordova plugin registry.
    [jsPaths addObject:@"www/cordova_plugins.js"];
    
    return jsPaths;
}

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

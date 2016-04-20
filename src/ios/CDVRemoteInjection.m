//
//  CDVRemoteInjection.m
//

#import "CDVRemoteInjection.h"
#import <Foundation/Foundation.h>

@implementation CDVRemoteInjectionWebViewNotificationDelegate

- (void)webViewDidStartLoad:(UIWebView*)theWebView
{
    [self.wrappedDelegate webViewDidStartLoad: theWebView];
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

@implementation CDVRemoteInjectionPlugin
- (UIWebView *) findWebView
{
    UIWebView *webView;
    if ([self respondsToSelector:@selector(webViewEngine)]) {
        // cordova-ios 4.0
        // TODO test that engineWebView is instance of UIWebView
        SEL selector = NSSelectorFromString(@"webViewEngine");
        SEL selectorWebView = NSSelectorFromString(@"engineWebView");
        
        webView = (UIWebView *)[[self performSelector:selector] performSelector:selectorWebView];
    } else {
        // < cordova-ios 4.0
        webView = (UIWebView *)[self webView];
    }
    
    return webView;
}
- (void) pluginInitialize
{
    [super pluginInitialize];
    
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
    NSString *setting  = @"CRIInjectFirstFiles";
    if ([self settingForKey:setting]) {
        NSString *value = [self settingForKey:setting];
        
        // Multiple files can be specified in the value, split the string on ",".
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        for (id path in [value componentsSeparatedByString:@","]) {
            [paths addObject: [self trim: path]];
        }
        
        [self setPreInjectionJSFiles: paths];
    } else {
        [self setPreInjectionJSFiles: [[NSArray alloc] init]];
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
 After page load inject cordova and its plugins.
 */
- (void) webViewDidFinishLoad:(NSNotification*)notification
{
    UIWebView *theWebView = notification.object;
    NSString *scheme = theWebView.request.URL.scheme;
    
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        [self injectCordova: theWebView];
    } else {
        NSLog(@"Unsupported scheme for cordova injection: %@.  Skipping...", scheme);
    }
}

- (void) injectCordova:(UIWebView*)theWebView
{
    NSArray *jsPaths = [self jsPathsToInject];
    
    NSString *path;
    for (path in jsPaths) {
        NSString *jsFilePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
        
        NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
        NSString *js = [NSString stringWithContentsOfFile:jsURL.path encoding:NSUTF8StringEncoding error:nil];
    
        NSLog(@"Injecting JS file into remote site: %@", jsURL.path);
        [theWebView stringByEvaluatingJavaScriptFromString:js];
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
    UIAlertView * alert =[[UIAlertView alloc ] initWithTitle:@"Load Error"
                                                     message:@"There was an issue contacting the server."
                                                    delegate:self
                                           cancelButtonTitle:@"Close"
                                           otherButtonTitles: nil];
    [alert addButtonWithTitle:@"Try again?"];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1)
    {
        [[self findWebView] reload];
    }
}

- (id)settingForKey:(NSString*)key
{
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

@end

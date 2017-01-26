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
    
    value = [self settingForKey:@"CRIShowConnectionErrorDialog"];
    if ([value isEqual: @"0"]) {
        _showConnectionErrorDialog = NO;
    } else {
        // By default the dialog is displayed.
        _showConnectionErrorDialog = YES;
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
 * Reads preferences from the configuration.
 */
- (id)settingForKey:(NSString *)key
{
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

@end

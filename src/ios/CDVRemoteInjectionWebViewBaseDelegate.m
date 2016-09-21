#import <Foundation/Foundation.h>

#import "CDVRemoteInjection.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

/*
 Objective-C wonkiness to create a property that can be accessed
 by subclasses but not on the exported public interface.
 */
@interface CDVRemoteInjectionWebViewBaseDelegate ()
@property (readwrite, weak) CDVRemoteInjectionPlugin *plugin;
@end

@implementation CDVRemoteInjectionWebViewBaseDelegate
- (id) initWithPlugin:(CDVRemoteInjectionPlugin *) injectionPlugin
{
    if ( self = [super init] ) {
        self.plugin = injectionPlugin;
        return self;
    } else {
        return nil;
    }
}

/*
 Builds a string of JS to inject into the web view.
 */
- (NSString *) buildInjectionJS;
{
    NSArray *jsPaths = [self jsPathsToInject];
    
    NSString *path;
    NSMutableString *concatenatedJS = [[NSMutableString alloc] init];
    
    for (path in jsPaths) {
        NSString *jsFilePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
        
        NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
        NSString *js = [NSString stringWithContentsOfFile:jsURL.path encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"Concatenating JS found in path: '%@'", jsURL.path);
        
        [concatenatedJS appendString:js];
    }
    return concatenatedJS;
}

/*
 Returns an array of bundled javascript files to inject into the current page.
 */
- (NSArray *) jsPathsToInject
{
    // Array of paths that represent JS files to inject into the WebView.  Order is important.
    NSMutableArray *jsPaths = [NSMutableArray new];
    
    // Pre injection files.
    for (id path in self.plugin.injectFirstFiles) {
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

/*
 Returns YES if the URL scheme is supported for JS injection.
 */
- (BOOL) isSupportedURLScheme:(NSString *) scheme
{
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        return YES;
    }
    
    NSLog(@"Unsupported scheme for cordova injection: '%@'.  Skipping.", scheme);
    return NO;
}

@end

@implementation WrappedDelegateProxy
- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ([super respondsToSelector:aSelector] || [self.wrappedDelegate respondsToSelector:aSelector]) {
        return YES;
    }
    return NO;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if ([self.wrappedDelegate respondsToSelector:[anInvocation selector]])
        [anInvocation invokeWithTarget:self.wrappedDelegate];
    else
        [super forwardInvocation:anInvocation];
}
@end

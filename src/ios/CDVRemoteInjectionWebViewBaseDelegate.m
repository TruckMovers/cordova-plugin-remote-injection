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

@end

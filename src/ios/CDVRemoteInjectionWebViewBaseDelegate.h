#import "CDVRemoteInjection.h"

@interface CDVRemoteInjectionWebViewBaseDelegate: NSObject
- (id) initWithPlugin: (CDVRemoteInjectionPlugin *) plugin;
- (NSArray *) jsPathsToInject;
@end

#import "CDVRemoteInjection.h"

/*
 Contains common code between web view delegate implementations.
 */
@interface CDVRemoteInjectionWebViewBaseDelegate: NSObject
- (id) initWithPlugin: (CDVRemoteInjectionPlugin *) plugin;
- (NSArray *) jsPathsToInject;
- (NSString *) buildInjectionJS;
- (BOOL) isSupportedURLScheme:(NSString *) scheme;
@end

/*
 Base implementation of a simple proxy that forwards unimplemented messages to a 
 wrappedDelegate property.
 */
@interface WrappedDelegateProxy: NSObject
@property (readwrite, retain) id wrappedDelegate;
- (BOOL)respondsToSelector:(SEL)aSelector;
- (void)forwardInvocation:(NSInvocation *)anInvocation;
@end

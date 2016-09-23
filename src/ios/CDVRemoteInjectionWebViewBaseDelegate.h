#import "CDVRemoteInjection.h"

/*
 * Contains common code between web view delegate implementations.  This class is the engine
 * containing the common logic in regards to prompting the user for long requests and failures
 * to load pages.  For each type of web view there should be a delegate that hooks into the
 * process via extension.
 */
@interface CDVRemoteInjectionWebViewBaseDelegate: NSObject
@property (readonly) NSInteger promptInterval;
- (id) initWithPlugin: (CDVRemoteInjectionPlugin *) plugin;
- (NSArray *) jsPathsToInject;
- (NSString *) buildInjectionJS;
- (BOOL) isSupportedURLScheme:(NSString *) scheme;
- (void) cancelRequestTimer;
- (void) retryCurrentRequest;
/*
 * Should be invoked by the subclass when the webview is making a request to load a page.
 */
- (void) webViewRequestStart;
/*
 * Should be invoked by the subclass when the page fails to load because of an error.
 */
- (void) loadPageFailure;
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

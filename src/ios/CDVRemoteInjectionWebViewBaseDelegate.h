#import "CDVRemoteInjection.h"

/*
 * Contains common code between web view delegate implementations.  This class is the engine
 * containing the common logic in regards to prompting the user for long requests and failures
 * to load pages.  For each type of web view there should be a delegate that hooks into the
 * process via extension.
 */
@interface CDVRemoteInjectionWebViewBaseDelegate: NSObject <CDVRemoteInjectionWebViewDelegate>
@property (readonly) NSInteger promptInterval;
- (NSArray *) jsPathsToInject;
- (NSString *) buildInjectionJS;
- (BOOL) isSupportedURLScheme:(NSString *) scheme;
- (void) cancelRequestTimer;
- (void) retryCurrentRequest;
- (void) webViewRequestStart;
- (void) loadPageFailure:(NSError *) error;
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

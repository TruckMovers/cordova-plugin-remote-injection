#if !WK_WEB_VIEW_ONLY

#import "CDVRemoteInjection.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

@interface CDVRemoteInjectionUIWebViewDelegate: CDVRemoteInjectionWebViewBaseDelegate <CDVRemoteInjectionWebViewDelegate>
@property (readwrite, weak) CDVRemoteInjectionPlugin *plugin;
- (void) onWebViewDidStartLoad;
- (void) onWebViewDidFinishLoad:(UIWebView *)webView;
- (void) onWebViewFailLoadWithError:(NSError *)error;
@end

@interface CDVRemoteInjectionUIWebViewNotificationDelegate : WrappedDelegateProxy <UIWebViewDelegate>
@property (readwrite, weak) CDVRemoteInjectionUIWebViewDelegate *webViewDelegate;
@end

#endif
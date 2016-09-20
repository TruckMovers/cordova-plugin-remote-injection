#import "CDVRemoteInjection.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

#define kCDVRemoteInjectionUIWebViewDidStartLoad @"CDVRemoteInjectionUIWebViewDidStartLoad"
#define kCDVRemoteInjectionUIWebViewDidFinishLoad @"CDVRemoteInjectionUIWebViewDidFinishLoad"
#define kCDVRemoteInjectionUIWebViewDidFailLoadWithError @"CDVRemoteInjectionUIWebViewDidFailLoadWithError"

@interface CDVRemoteInjectionUIWebViewNotificationDelegate : NSObject <UIWebViewDelegate>
@property (readwrite, retain) id<UIWebViewDelegate> wrappedDelegate;
@end

@interface CDVRemoteInjectionUIWebViewDelegate: CDVRemoteInjectionWebViewBaseDelegate <CDVRemoteInjectionWebViewDelegate>
@property (readwrite, weak) CDVRemoteInjectionPlugin *plugin;
@end

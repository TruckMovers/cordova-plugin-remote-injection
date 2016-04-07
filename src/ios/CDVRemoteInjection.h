//
//  CDVRemoteInjection.h
//

#import <Cordova/CDVPlugin.h>

#define kCDVRemoteInjectionWebViewDidFinishLoad @"CDVRemoveInjectionWebViewDidFinishLoad"
#define kCDVRemoteInjectionWebViewDidFailLoadWithError @"CDVRemoteInjectionWebViewDidFailLoadWithError"

@interface CDVRemoteInjectionWebViewNotificationDelegate : NSObject <UIWebViewDelegate>
    @property (nonatomic,retain) id<UIWebViewDelegate> wrappedDelegate;
@end

@interface CDVRemoteInjectionPlugin : CDVPlugin
{
    CDVRemoteInjectionWebViewNotificationDelegate *notificationDelegate;
}

@property NSArray *preInjectionJSFiles;

@end

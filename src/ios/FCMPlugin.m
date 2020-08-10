#include <sys/types.h>
#include <sys/sysctl.h>

#import "AppDelegate+FCMPlugin.h"

#import <Cordova/CDV.h>
#import "FCMPlugin.h"
#import "Firebase.h"

@interface FCMPlugin () {}
@end

@implementation FCMPlugin

static BOOL notificatorReceptorReady = NO;
static BOOL appInForeground = YES;

static NSString *notificationCallback = @"FCMPlugin.onNotificationReceived";
static NSString *tokenRefreshCallback = @"FCMPlugin.onTokenRefreshReceived";
static FCMPlugin *fcmPluginInstance;

NSString* domainUriPrefix;
NSString* dynamicLinkCallbackId;
NSDictionary* lastDynamicLinkData;

+ (FCMPlugin *) fcmPlugin {
    
    return fcmPluginInstance;
}

- (void) ready:(CDVInvokedUrlCommand *)command
{
    NSLog(@"Cordova view ready");
    fcmPluginInstance = self;
    domainUriPrefix = [self.commandDelegate.settings objectForKey:[@"DYNAMIC_LINK_URIPREFIX" lowercaseString]];
    [self.commandDelegate runInBackground:^{
        
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// GET TOKEN //
- (void) getToken:(CDVInvokedUrlCommand *)command 
{
    NSLog(@"get Token");
    [self.commandDelegate runInBackground:^{
        // NSString* token = [[FIRInstanceID instanceID] token];
        NSString* token = [FIRMessaging messaging].FCMToken;
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// UN/SUBSCRIBE TOPIC //
- (void) subscribeToTopic:(CDVInvokedUrlCommand *)command 
{
    NSString* topic = [command.arguments objectAtIndex:0];
    NSLog(@"subscribe To Topic %@", topic);
    [self.commandDelegate runInBackground:^{
        if(topic != nil)[[FIRMessaging messaging] subscribeToTopic:[NSString stringWithFormat:@"%@", topic]];
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:topic];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) unsubscribeFromTopic:(CDVInvokedUrlCommand *)command 
{
    NSString* topic = [command.arguments objectAtIndex:0];
    NSLog(@"unsubscribe From Topic %@", topic);
    [self.commandDelegate runInBackground:^{
        if(topic != nil)[[FIRMessaging messaging] unsubscribeFromTopic:[NSString stringWithFormat:@"%@", topic]];
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:topic];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) registerNotification:(CDVInvokedUrlCommand *)command
{
    NSLog(@"view registered for notifications");
    
    notificatorReceptorReady = YES;
    NSData* lastPush = [AppDelegate getLastPush];
    if (lastPush != nil) {
        [FCMPlugin.fcmPlugin notifyOfMessage:lastPush];
    }
    
    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) notifyOfMessage:(NSData *)payload
{
    NSString *JSONString = [[NSString alloc] initWithBytes:[payload bytes] length:[payload length] encoding:NSUTF8StringEncoding];
    NSString * notifyJS = [NSString stringWithFormat:@"%@(%@);", notificationCallback, JSONString];
    NSLog(@"stringByEvaluatingJavaScriptFromString %@", notifyJS);
    
    if ([self.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        [(UIWebView *)self.webView stringByEvaluatingJavaScriptFromString:notifyJS];
    } else {
        [self.webViewEngine evaluateJavaScript:notifyJS completionHandler:nil];
    }
}

-(void) notifyOfTokenRefresh:(NSString *)token
{
    NSString * notifyJS = [NSString stringWithFormat:@"%@('%@');", tokenRefreshCallback, token];
    NSLog(@"stringByEvaluatingJavaScriptFromString %@", notifyJS);
    
    if ([self.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        [(UIWebView *)self.webView stringByEvaluatingJavaScriptFromString:notifyJS];
    } else {
        [self.webViewEngine evaluateJavaScript:notifyJS completionHandler:nil];
    }
}

-(void) appEnterBackground
{
    NSLog(@"Set state background");
    appInForeground = NO;
}

-(void) appEnterForeground
{
    NSLog(@"Set state foreground");
    NSData* lastPush = [AppDelegate getLastPush];
    if (lastPush != nil) {
        [FCMPlugin.fcmPlugin notifyOfMessage:lastPush];
    }
    appInForeground = YES;
}

// Firebase Analytics

- (void) logEvent: (CDVInvokedUrlCommand *)command {
    NSLog(@"logEvent");

    NSString* name = [command.arguments objectAtIndex:0];
    NSDictionary* parameters = [command.arguments objectAtIndex:1];

    [FIRAnalytics logEventWithName:name parameters:parameters];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    NSLog(@"setUserId");

    NSString* id = [command.arguments objectAtIndex:0];

    [FIRAnalytics setUserID:id];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    NSLog(@"setUserProperty");

    NSString* name = [command.arguments objectAtIndex:0];
    NSString* value = [command.arguments objectAtIndex:1];

    [FIRAnalytics setUserPropertyString:value forName:name];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Clear all notifications
- (void) clearAllNotifications: (CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
      [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
      [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// Dynamic Links

- (void)onDynamicLink:(CDVInvokedUrlCommand *)command {
    dynamicLinkCallbackId = command.callbackId;

    if (lastDynamicLinkData) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:lastDynamicLinkData];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:dynamicLinkCallbackId];

        lastDynamicLinkData = nil;
    }
}

- (void)createDynamicLink:(CDVInvokedUrlCommand *)command {
    NSDictionary* params = [command.arguments objectAtIndex:0];
    int linkType = [[command.arguments objectAtIndex:1] intValue];
    FIRDynamicLinkComponents *linkBuilder = [self createDynamicLinkBuilder:params];

    if (linkType == 0) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:linkBuilder.url.absoluteString];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
        linkBuilder.options = [[FIRDynamicLinkComponentsOptions alloc] init];
        linkBuilder.options.pathLength = linkType;

        [linkBuilder shortenWithCompletion:^(NSURL * _Nullable shortURL,
                                             NSArray<NSString *> * _Nullable warnings,
                                             NSError * _Nullable error) {
            CDVPluginResult *pluginResult;
            if (error) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
            } else if (shortURL) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:shortURL.absoluteString];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:nil];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }
}

- (FIRDynamicLinkComponents*) createDynamicLinkBuilder:(NSDictionary*) params {
    NSURL* link = [[NSURL alloc] initWithString:params[@"link"]];
    NSString* domainUriPrefix2 = params[@"domainUriPrefix"];
    if (!domainUriPrefix2) {
        domainUriPrefix = domainUriPrefix2;
    }

    FIRDynamicLinkComponents *linkBuilder = [[FIRDynamicLinkComponents alloc]
                                             initWithLink:link domainURIPrefix:domainUriPrefix];
    NSDictionary* androidInfo = params[@"androidInfo"];
    if (androidInfo) {
        linkBuilder.androidParameters = [self getAndroidParameters:androidInfo];
    }
    NSDictionary* iosInfo = params[@"iosInfo"];
    if (iosInfo) {
        linkBuilder.iOSParameters = [self getIosParameters:iosInfo];
    }
    NSDictionary* navigationInfo = params[@"navigationInfo"];
    if (navigationInfo) {
        linkBuilder.navigationInfoParameters = [self getNavigationInfoParameters:navigationInfo];
    }
    NSDictionary* analyticsInfo = params[@"analyticsInfo"];
    if (analyticsInfo) {
        NSDictionary* googlePlayAnalyticsInfo = params[@"googlePlayAnalytics"];
        if (googlePlayAnalyticsInfo) {
            linkBuilder.analyticsParameters = [self getGoogleAnalyticsParameters:googlePlayAnalyticsInfo];
        }
        NSDictionary* itunesConnectAnalyticsInfo = params[@"itunesConnectAnalytics"];
        if (itunesConnectAnalyticsInfo) {
            linkBuilder.iTunesConnectParameters = [self getItunesConnectAnalyticsParameters:itunesConnectAnalyticsInfo];
        }
    }
    NSDictionary* socialMetaTagInfo = params[@"socialMetaTagInfo"];
    if (socialMetaTagInfo) {
        linkBuilder.socialMetaTagParameters = [self getSocialMetaTagParameters:socialMetaTagInfo];
    }
    return linkBuilder;
}

- (FIRDynamicLinkAndroidParameters*) getAndroidParameters:(NSDictionary*) androidInfo {
    FIRDynamicLinkAndroidParameters* result = [[FIRDynamicLinkAndroidParameters alloc]
                                     initWithPackageName:androidInfo[@"androidPackageName"]];
    NSNumber* minimumVersion = androidInfo[@"androidMinPackageVersionCode"];
    if (minimumVersion) {
        result.minimumVersion = [minimumVersion intValue];
    }
    NSString* androidFallbackLink = androidInfo[@"androidFallbackLink"];
    if (androidFallbackLink) {
        result.fallbackURL = [[NSURL alloc] initWithString:androidFallbackLink];
    }
    return result;
}

- (FIRDynamicLinkIOSParameters*) getIosParameters:(NSDictionary*) iosInfo {
    FIRDynamicLinkIOSParameters* result = [[FIRDynamicLinkIOSParameters alloc]
                                 initWithBundleID:iosInfo[@"iosBundleId"]];
    result.appStoreID = iosInfo[@"iosAppStoreId"];
    result.iPadBundleID = iosInfo[@"iosIpadBundleId"];
    result.minimumAppVersion = iosInfo[@"iosMinPackageVersion"];
    NSString* iosFallbackLink = iosInfo[@"iosFallbackLink"];
    if (iosFallbackLink) {
        result.fallbackURL = [[NSURL alloc] initWithString:iosFallbackLink];
    }
    NSString* iosIpadFallbackLink = iosInfo[@"iosIpadFallbackLink"];
    if (iosIpadFallbackLink) {
        result.iPadFallbackURL = [[NSURL alloc] initWithString:iosIpadFallbackLink];
    }
    return result;
}

- (FIRDynamicLinkNavigationInfoParameters*) getNavigationInfoParameters:(NSDictionary*) navigationInfo {
    FIRDynamicLinkNavigationInfoParameters* result = [[FIRDynamicLinkNavigationInfoParameters alloc] init];
    NSNumber* forcedRedirectEnabled = navigationInfo[@"enableForcedRedirect"];
    if (forcedRedirectEnabled) {
        result.forcedRedirectEnabled = [forcedRedirectEnabled boolValue];
    }
    return result;
}

- (FIRDynamicLinkGoogleAnalyticsParameters*) getGoogleAnalyticsParameters:(NSDictionary*) googlePlayAnalyticsInfo {
    FIRDynamicLinkGoogleAnalyticsParameters* result = [[FIRDynamicLinkGoogleAnalyticsParameters alloc] init];
    result.source = googlePlayAnalyticsInfo[@"utmSource"];
    result.medium = googlePlayAnalyticsInfo[@"utmMedium"];
    result.campaign = googlePlayAnalyticsInfo[@"utmCampaign"];
    result.content = googlePlayAnalyticsInfo[@"utmContent"];
    result.term = googlePlayAnalyticsInfo[@"utmTerm"];
    return result;
}

- (FIRDynamicLinkItunesConnectAnalyticsParameters*) getItunesConnectAnalyticsParameters:(NSDictionary*) itunesConnectAnalyticsInfo {
    FIRDynamicLinkItunesConnectAnalyticsParameters* result = [[FIRDynamicLinkItunesConnectAnalyticsParameters alloc] init];
    result.affiliateToken = itunesConnectAnalyticsInfo[@"at"];
    result.campaignToken = itunesConnectAnalyticsInfo[@"ct"];
    result.providerToken = itunesConnectAnalyticsInfo[@"pt"];
    return result;
}

- (FIRDynamicLinkSocialMetaTagParameters*) getSocialMetaTagParameters:(NSDictionary*) socialMetaTagInfo {
    FIRDynamicLinkSocialMetaTagParameters* result = [[FIRDynamicLinkSocialMetaTagParameters alloc] init];
    result.title = socialMetaTagInfo[@"socialTitle"];
    result.descriptionText = socialMetaTagInfo[@"socialDescription"];
    NSString* socialImageLink = socialMetaTagInfo[@"socialImageLink"];
    if (socialImageLink) {
        result.imageURL = [[NSURL alloc] initWithString:socialImageLink];
    }
    return result;
}

- (void)postDynamicLink:(FIRDynamicLink*) dynamicLink {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSString* absoluteUrl = dynamicLink.url.absoluteString;
    NSString* minimumAppVersion = dynamicLink.minimumAppVersion;
    BOOL weakConfidence = (dynamicLink.matchType == FIRDLMatchTypeWeak);

    [data setObject:(absoluteUrl ? absoluteUrl : @"") forKey:@"deepLink"];
    [data setObject:(minimumAppVersion ? minimumAppVersion : @"") forKey:@"minimumAppVersion"];
    [data setObject:(weakConfidence ? @"Weak" : @"Strong") forKey:@"matchType"];

    if (dynamicLinkCallbackId) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:dynamicLinkCallbackId];
    } else {
        lastDynamicLinkData = data;
    }
}


@end

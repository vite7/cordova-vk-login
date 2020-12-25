//
//  VkSdkPlugin.h

#import <Cordova/CDV.h>
@import VK_ios_sdk;

@interface VkSdkPlugin : CDVPlugin <VKSdkDelegate, VKSdkUIDelegate>
{
    NSString*     clientId;
}

@property (nonatomic, retain) NSString*     clientId;

- (void)initVkSdk:(CDVInvokedUrlCommand*)command;
- (void)loginVkSdk:(CDVInvokedUrlCommand*)command;
- (void)logout:(CDVInvokedUrlCommand*)command;
- (void)getUser:(CDVInvokedUrlCommand*)command;


@end

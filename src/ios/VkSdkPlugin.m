//
//  VkSdkPlugin.m

@import VK_ios_sdk;
#import "VkSdkPlugin.h"

@implementation VkSdkPlugin {
    NSString * pluginCallbackId;
    CDVInvokedUrlCommand *savedCommand;
    void (^vkCallBackBlock)(NSString *, NSString *, NSString *);
    BOOL inited;
    NSMutableDictionary *loginDetails;
    NSArray *_permissions;
    VKSdk* _vkSdk;
    BOOL _tryToAuthAgain;
}

@synthesize clientId;

- (void) initVkSdk:(CDVInvokedUrlCommand*)command
{
    _permissions = @[@"photos", @"offline"];
    CDVPluginResult* pluginResult = nil;
    
    if (pluginCallbackId == nil) {
        NSString *appId = [[NSString alloc] initWithString:[command.arguments objectAtIndex:0]];
        _vkSdk = [VKSdk initializeWithAppId:appId];
        [_vkSdk registerDelegate:self];
        [_vkSdk setUiDelegate:self];
        [VKSdk wakeUpSession:_permissions completeBlock:^(VKAuthorizationState state, NSError *error) {
            if (error) {
                NSLog(@"VK init error!");
            }
        }];
        
        NSLog(@"VkSdkPlugin Plugin initalized");
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myOpenUrl:) name:CDVPluginHandleOpenURLWithAppSourceAndAnnotationNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myOpenUrl:) name:CDVPluginHandleOpenURLNotification object:nil];
        
        NSDictionary *errorObject = @{
            @"eventType" : @"initialized",
            @"eventData" : @"success"
        };
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:errorObject];
        pluginCallbackId = command.callbackId;
    } else {
        NSDictionary *errorObject = @{
            @"code" : @"initError",
            @"message" : @"Plugin was already initialized"
        };
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorObject];
    }
    
    pluginResult.keepCallback = [NSNumber numberWithBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) loginVkSdk:(CDVInvokedUrlCommand*)command
{
    NSArray *permissions = [command.arguments objectAtIndex:0];
    [self vkLoginWithBlock:permissions block:^(NSString *token, NSString *userId, NSString *expiresIn) {
        CDVPluginResult* pluginResult = nil;
        if(token) {
            NSLog(@"Acquired new VK token");
            NSDictionary *result = @{
                @"eventType" : @"newToken",
                @"eventData" : @{
                    @"accessToken" : token,
                    @"userId" : userId,
                    @"expiresIn": expiresIn,
                    @"secret": @""
                }
            };
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
            
        } else {
            NSLog(@"Cant login to VKontakte");
            NSDictionary *errorObject = @{
                @"code" : @"loginError",
                @"message" : @"Cant login to VKontakte"
            };
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorObject];
        }
        pluginResult.keepCallback = [NSNumber numberWithBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self->pluginCallbackId];
    }];

}

-(UIViewController*)findViewController
{
    id vc = self.webView;
    do {
        vc = [vc nextResponder];
    } while([vc isKindOfClass:UIView.class]);
    return vc;
}

-(void)myOpenUrl:(NSNotification*)notification
{
    NSURL *url = notification.object[@"url"];
    if(![url isKindOfClass:NSURL.class]) return;
    BOOL wasHandled = [VKSdk processOpenURL:url fromApplication:nil];
}

-(void)vkLoginWithBlock:(NSArray *)permissions block:(void (^)(NSString *, NSString *, NSString *))block
{
    _tryToAuthAgain = true;
    vkCallBackBlock = [block copy];
    [VKSdk authorize: permissions];
    
    if (_tryToAuthAgain) {
        [VKSdk authorize: permissions];
    }
}

-(void)logout:(CDVInvokedUrlCommand *)command
{
    [VKSdk forceLogout];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getUser:(CDVInvokedUrlCommand*)command;
{
    NSDictionary *reqParams = @{
        VK_API_USER_ID: [[NSString alloc] initWithString:[command.arguments objectAtIndex:0]],
        VK_API_FIELDS: @"id, first_name, sex, bdate"
    };
    VKRequest * userGetReq = [[VKApi users] get:reqParams];
    [userGetReq executeWithResultBlock:^(VKResponse * response) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response.json];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        NSLog(@"Json result: %@", response.json);
    } errorBlock:^(NSError * error) {
        if (error.code != VK_API_ERROR) {
            [error.vkError.request repeat];
        } else {
            NSLog(@"VK error: %@", error);
            NSDictionary *errorObject = @{
                @"code" : @"loginError",
                @"message" : @"Cant get user",
                @"details": error.domain
            };
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorObject];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } 
    }];
}

#pragma mark - VKSdkDelegate

- (void)vkSdkAuthorizationStateUpdatedWithResult:(VKAuthorizationResult *)result {
    NSLog(@"State updated");
}

- (void)vkSdkAccessTokenUpdated:(VKAccessToken *)newToken oldToken:(VKAccessToken *)oldToken {
    NSLog(@"VK Token %@", newToken.accessToken);
    if(vkCallBackBlock) vkCallBackBlock(newToken.accessToken, newToken.userId, [NSString stringWithFormat:@"%ld", newToken.expiresIn]);
}

- (void)vkSdkRenewedToken:(VKAccessToken *)newToken
{
    NSLog(@"VK Token %@", newToken.accessToken);
    if(vkCallBackBlock) vkCallBackBlock(newToken.accessToken, newToken.userId, [NSString stringWithFormat:@"%ld", newToken.expiresIn]);
}

-(void) vkSdkUserDeniedAccess:(VKError*) authorizationError
{
    NSLog(@"VK Error %@", authorizationError);
    if(vkCallBackBlock) vkCallBackBlock(nil, nil, nil);
}


-(void) vkSdkShouldPresentViewController:(UIViewController *)controller
{
    NSLog(@"VK Wants controller!");
    _tryToAuthAgain = false;
    [[self findViewController] presentViewController:controller animated:YES completion:nil];
}

-(void) vkSdkTokenHasExpired:(VKAccessToken *)expiredToken
{
    
}

- (void)vkSdkAccessAuthorizationFinishedWithResult:(VKAuthorizationResult *)result {
    NSLog(@"dsds");
}


- (void)vkSdkUserAuthorizationFailed {
    NSLog(@"dsds2");
}


-(void) vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
    NSLog(@"Need captcha %@", captchaError);
}

-(BOOL)vkSdkAuthorizationAllowFallbackToSafari
{
    return NO;
}

-(BOOL)vkSdkIsBasicAuthorization
{
    return YES;
}

@end

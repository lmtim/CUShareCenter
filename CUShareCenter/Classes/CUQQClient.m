//
//  CUQQClient.m
//  Example
//
//  Created by curer on 13-10-27.
//  Copyright (c) 2013年 curer. All rights reserved.
//

#import "CUQQClient.h"
#import "PlatFormModel.h"
#import "CUPlatFormOAuth.h"
#import "CUPlatFormUserModel.h"
#import <CURestKit/CURestkit.h>

#import <TencentOpenAPI/TencentOAuth.h>
#import <TencentOpenAPI/TencentApiInterface.h>

#define QQ_ACCESSTOKEN_KEY    @"com.tencent.QQ.accessToken"
#define QQ_OPENID_KEY         @"com.tencent.QQ.openId"
#define QQ_EXPIRATIONDATE_KEY @"com.tencent.QQ.expirationDate"

@interface CUQQClient ()

@property (nonatomic, strong) TencentOAuth *qqOAuthSDK;
@property (nonatomic, strong) void (^successBlock)(NSString *message, id data);
@property (nonatomic, strong) void (^failedBlock)( NSString *message, id data);

@property (nonatomic, strong) ASIHTTPRequest *request;

@end

@implementation CUQQClient

+ (CUQQClient *)sharedInstance:(PlatFormModel *)model {
    static CUQQClient *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[CUQQClient alloc] init];
        [_sharedInstance setupWithPlatForm:model];
    });
    
    return _sharedInstance;
}

- (void)setupWithPlatForm:(PlatFormModel *)model
{
    self.qqOAuthSDK = [[TencentOAuth alloc] initWithAppId:model.appKey
                                                         andDelegate:self];
    if (model.redirectUri.length > 0) {
        self.qqOAuthSDK.redirectURI = model.redirectUri;
    }
    
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:QQ_ACCESSTOKEN_KEY];
    NSString *openId = [[NSUserDefaults standardUserDefaults] objectForKey:QQ_OPENID_KEY];
    NSDate *experationDate = [[NSUserDefaults standardUserDefaults] objectForKey:QQ_EXPIRATIONDATE_KEY];
    
    if (accessToken != nil) {
        self.qqOAuthSDK.accessToken = accessToken;
        self.qqOAuthSDK.expirationDate = experationDate;
        self.qqOAuthSDK.openId = openId;
    }
}

- (id)initWithPlatForm:(PlatFormModel *)model
{
    //tencent qq 的sdk很奇怪，必须单例才能保证结果和预期一致，否则则会不经意的crash
    //而且他的demo也是单例，这个和我们最初的设计不符合，但是没有办法。太dt
    return [CUQQClient sharedInstance:model];
}

#pragma mark - Bind/unBind

- (void)bindSuccess:(void (^)(NSString *message, id data))success error:(void (^)(NSString *message, id data))errorBlock
{
    self.successBlock = [success copy];
    self.failedBlock = [errorBlock copy];
    
    NSArray* permissions = [NSArray arrayWithObjects:
                            kOPEN_PERMISSION_GET_USER_INFO,
                            kOPEN_PERMISSION_GET_SIMPLE_USER_INFO,
                            kOPEN_PERMISSION_ADD_ALBUM,
                            kOPEN_PERMISSION_ADD_IDOL,
                            kOPEN_PERMISSION_ADD_ONE_BLOG,
                            kOPEN_PERMISSION_ADD_PIC_T,
                            kOPEN_PERMISSION_ADD_SHARE,
                            kOPEN_PERMISSION_ADD_TOPIC,
                            kOPEN_PERMISSION_CHECK_PAGE_FANS,
                            kOPEN_PERMISSION_DEL_IDOL,
                            kOPEN_PERMISSION_DEL_T,
                            kOPEN_PERMISSION_GET_FANSLIST,
                            kOPEN_PERMISSION_GET_IDOLLIST,
                            kOPEN_PERMISSION_GET_INFO,
                            kOPEN_PERMISSION_GET_OTHER_INFO,
                            kOPEN_PERMISSION_GET_REPOST_LIST,
                            kOPEN_PERMISSION_LIST_ALBUM,
                            kOPEN_PERMISSION_UPLOAD_PIC,
                            kOPEN_PERMISSION_GET_VIP_INFO,
                            kOPEN_PERMISSION_GET_VIP_RICH_INFO,
                            kOPEN_PERMISSION_GET_INTIMATE_FRIENDS_WEIBO,
                            kOPEN_PERMISSION_MATCH_NICK_TIPS_WEIBO,
                            //微云的api权限
                            @"upload_pic",
                            @"download_pic",
                            @"get_pic_list",
                            @"delete_pic",
                            @"upload_pic",
                            @"download_pic",
                            @"get_pic_list",
                            @"delete_pic",
                            @"get_pic_thumb",
                            @"upload_music",
                            @"download_music",
                            @"get_music_list",
                            @"delete_music",
                            @"upload_video",
                            @"download_video",
                            @"get_video_list",
                            @"delete_video",
                            @"upload_photo",
                            @"download_photo",
                            @"get_photo_list",
                            @"delete_photo",
                            @"get_photo_thumb",
                            @"check_record",
                            @"create_record",
                            @"delete_record",
                            @"get_record",
                            @"modify_record",
                            @"query_all_record",
                            nil];
    
    [self.qqOAuthSDK logout:self];
    [self.qqOAuthSDK authorize:permissions inSafari:NO];
}

- (void)unBind
{
    [self.qqOAuthSDK logout:nil];
}
- (BOOL)isBind;
{
    return [self.qqOAuthSDK isSessionValid];
}

- (void)clear
{
    self.successBlock = nil;
    self.failedBlock = nil;
    
    [self.request clearDelegatesAndCancel];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [TencentOAuth HandleOpenURL:url];
}

#pragma mark - QQSDKDelegate

- (void)tencentDidLogin
{
    [[NSUserDefaults standardUserDefaults] setObject:self.qqOAuthSDK.accessToken forKey:QQ_ACCESSTOKEN_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:self.qqOAuthSDK.openId forKey:QQ_OPENID_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:self.qqOAuthSDK.expirationDate forKey:QQ_EXPIRATIONDATE_KEY];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.successBlock) {
        self.successBlock(@"success", nil);
    }
    
    [self clear];
}

/**
 * 登录失败后的回调
 * \param cancelled 代表用户是否主动退出登录
 */
- (void)tencentDidNotLogin:(BOOL)cancelled
{
    if (self.failedBlock) {
        self.failedBlock(@"error", nil);
    }
    
    [self clear];
}

/**
 * 登录时网络有问题的回调
 */
- (void)tencentDidNotNetWork
{
    if (self.failedBlock) {
        self.failedBlock(@"error", nil);
    }
    
    [self clear];
}

@end

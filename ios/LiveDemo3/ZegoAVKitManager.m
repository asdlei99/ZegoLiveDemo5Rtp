//
//  ZegoAVKitManager.m
//  LiveDemo
//
//  Copyright © 2015年 Zego. All rights reserved.
//

#include "ZegoAVKitManager.h"
#import "ZegoSettings.h"
#import "ZegoVideoFilterDemo.h"

#import <ZegoLiveRoom/ZegoLiveRoomApi-AudioIO.h>

NSString *kZegoDemoAppTypeKey          = @"apptype";
NSString *kZegoDemoAppIDKey            = @"appid";
NSString *kZegoDemoAppSignKey          = @"appsign";


static ZegoLiveRoomApi *g_ZegoApi = nil;

//NSData *g_signKey = nil;
//uint32_t g_appID = 0;

BOOL g_useTestEnv = NO;
BOOL g_useAlphaEnv = NO;

// Demo 默认版本为 UDP
ZegoAppType g_appType = ZegoAppTypeUDP;

#if TARGET_OS_SIMULATOR
BOOL g_useHardwareEncode = NO;
BOOL g_useHardwareDecode = NO;
#else
BOOL g_useHardwareEncode = YES;
BOOL g_useHardwareDecode = YES;
#endif

BOOL g_enableVideoRateControl = NO;

BOOL g_useExternalCaptrue = NO;
BOOL g_useExternalRender = NO;

BOOL g_enableReverb = NO;

BOOL g_recordTime = NO;
BOOL g_useInternationDomain = NO;
BOOL g_useExternalFilter = NO;

BOOL g_useHeadSet = NO;

static Byte toByte(NSString* c);
static NSData* ConvertStringToSign(NSString* strSign);

static __strong id<ZegoVideoCaptureFactory> g_factory = nullptr;
static __strong id<ZegoVideoFilterFactory> g_filterFactory = nullptr;

@interface ZegoDemoHelper ()

+ (void)setupVideoCaptureDevice;

@end

@implementation ZegoDemoHelper

+ (ZegoLiveRoomApi *)api
{
    if (g_ZegoApi == nil) {
        
        // 国际版，要切换国际域名
        if (g_appType == ZegoAppTypeI18N) {
            g_useInternationDomain = YES;
        } else {
            g_useInternationDomain = NO;
        }
        
        [ZegoLiveRoomApi setUseTestEnv:g_useTestEnv];
//        [ZegoLiveRoomApi performSelector:@selector(setUseAlphaEnv:) withObject:@(g_useAlphaEnv)];
        [ZegoLiveRoomApi enableExternalRender:[self usingExternalRender]];
        
#ifdef DEBUG
        [ZegoLiveRoomApi setVerbose:YES];
#endif
    
        [self setupVideoCaptureDevice];
        [self setupVideoFilter];
        
        [ZegoLiveRoomApi setUserID:[ZegoSettings sharedInstance].userID userName:[ZegoSettings sharedInstance].userName];
        
        uint32_t appID = [self appID];
        if (appID > 0) {    // 手动输入为空的情况下容错
            NSData *appSign = [self zegoAppSignFromServer];
            if (appSign) {
                g_ZegoApi = [[ZegoLiveRoomApi alloc] initWithAppID:appID appSignature:appSign];
            }
        }

        [g_ZegoApi enableAECWhenHeadsetDetected:false];
        [ZegoLiveRoomApi requireHardwareDecoder:g_useHardwareDecode];
        [ZegoLiveRoomApi requireHardwareEncoder:g_useHardwareEncode];
        
        if (g_appType == ZegoAppTypeUDP || g_appType == ZegoAppTypeI18N) {
            [g_ZegoApi enableTrafficControl:YES properties:ZEGOAPI_TRAFFIC_FPS | ZEGOAPI_TRAFFIC_RESOLUTION];
        }
    }
    
    return g_ZegoApi;
}

+ (void)checkHeadSet
{
#if TARGET_IPHONE_SIMULATOR
    g_useHeadSet = NO;
#else
    AVAudioSessionRouteDescription *route = [AVAudioSession sharedInstance].currentRoute;
    for (AVAudioSessionPortDescription *desc in route.outputs)
    {
        if ([desc.portType isEqualToString:AVAudioSessionPortHeadphones] ||
            [desc.portType isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [desc.portType isEqualToString:AVAudioSessionPortBluetoothHFP])
        {
            g_useHeadSet = YES;
            return;
        }
    }
    
    g_useHeadSet = NO;
#endif
}

+ (void)releaseApi
{
    g_ZegoApi = nil;
}

+ (void)setCustomAppID:(uint32_t)appid sign:(NSString *)sign
{
    NSData *d = ConvertStringToSign(sign);
    
    if (d.length == 32 && appid != 0)
    {
//        g_appID = appid;
//        g_signKey = [[NSData alloc] initWithData:d];
        
        // 持久化
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud setObject:@(appid) forKey:kZegoDemoAppIDKey];
        [ud setObject:sign forKey:kZegoDemoAppSignKey];
        
        g_ZegoApi = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RoomInstanceClear" object:nil userInfo:nil];
    }
}

+ (void)setUsingTestEnv:(bool)testEnv
{
    if (g_useTestEnv != testEnv)
    {
        [self releaseApi];
    }
    
    g_useTestEnv = testEnv;
    [ZegoLiveRoomApi setUseTestEnv:testEnv];
}

+ (bool)usingTestEnv
{
    return g_useTestEnv;
}

+ (bool)usingAlphaEnv
{
    return g_useAlphaEnv;
}

+ (void)setUsingExternalCapture:(bool)bUse
{
    if (g_useExternalCaptrue == bUse)
        return;
    
    [self releaseApi];
    
    g_useExternalCaptrue = bUse;
    if (bUse)
    {
#if TARGET_OS_SIMULATOR
        if (g_factory == nil)
            g_factory = [[ZegoVideoCaptureFactory alloc] init];
#else 
        if (g_factory == nil)
            g_factory = [[VideoCaptureFactoryDemo alloc] init];
#endif
        
        [ZegoLiveRoomApi setVideoCaptureFactory:g_factory];
    }
    else
    {
        [ZegoLiveRoomApi setVideoCaptureFactory:nil];
    }
}

#if TARGET_OS_SIMULATOR
+ (ZegoVideoCaptureFactory *)getVideoCaptureFactory
{
    return g_factory;
}
#else
+ (VideoCaptureFactoryDemo *)getVideoCaptureFactory
{
    return g_factory;
}
#endif

+ (bool)usingExternalCapture
{
    return g_useExternalCaptrue;
}

+ (void)setUsingExternalRender:(bool)bUse
{
    if (g_useExternalRender != bUse)
    {
        [self releaseApi];
    }
    
    g_useExternalRender = bUse;
    [ZegoLiveRoomApi enableExternalRender:bUse];
}

+ (bool)usingExternalRender
{
    return g_useExternalRender;
}

+ (void)setUsingExternalFilter:(bool)bUse
{
    if (g_useExternalFilter == bUse)
        return;
    
    [self releaseApi];
    
    g_useExternalFilter = bUse;
    if (bUse)
    {
        if (g_filterFactory == nullptr)
            g_filterFactory = [[ZegoVideoFilterFactoryDemo alloc] init];
        
        [ZegoLiveRoomApi setVideoFilterFactory:g_filterFactory];
    }
    else
    {
        [ZegoLiveRoomApi setVideoFilterFactory:nil];
    }
}

+ (bool)usingExternalFilter
{
    return g_useExternalFilter;
}

+ (void)setUsingHardwareDecode:(bool)bUse
{
    if (g_useHardwareDecode == bUse)
        return;
    
    g_useHardwareDecode = bUse;
    [ZegoLiveRoomApi requireHardwareDecoder:g_useHardwareDecode];
}

+ (bool)usingHardwareDecode
{
    return g_useHardwareDecode;
}

+ (void)setUsingHardwareEncode:(bool)bUse
{
    if (g_useHardwareEncode == bUse)
        return;
    
    if (bUse)
    {
        if (g_enableVideoRateControl)
        {
            g_enableVideoRateControl = NO;
            [g_ZegoApi enableRateControl:false];
        }
    }
    
    g_useHardwareEncode = bUse;
    [ZegoLiveRoomApi requireHardwareEncoder:g_useHardwareEncode];
}

+ (bool)usingHardwareEncode
{
    return g_useHardwareEncode;
}

+ (void)setEnableRateControl:(bool)bEnable
{
    if (g_enableVideoRateControl == bEnable)
        return;
    
    if (bEnable)
    {
        if (g_useHardwareEncode)
        {
            g_useHardwareEncode = NO;
            [ZegoLiveRoomApi requireHardwareEncoder:false];
        }
    }
    
    g_enableVideoRateControl = bEnable;
    [g_ZegoApi enableRateControl:g_enableVideoRateControl];
}

+ (bool)rateControlEnabled
{
    return g_enableVideoRateControl;
}

void prep_func(const short* inData, int inSamples, int sampleRate, short *outData)
{
    memcpy(outData, inData, inSamples * sizeof(short));
}

void prep2_func(const AVE::AudioFrame& inFrame, AVE::AudioFrame& outFrame)
{
    outFrame.frameType = inFrame.frameType;
    outFrame.samples = inFrame.samples;
    outFrame.bytesPerSample = inFrame.bytesPerSample;
    outFrame.channels = inFrame.channels;
    outFrame.sampleRate = inFrame.sampleRate;
    outFrame.timeStamp = inFrame.timeStamp;
    outFrame.configLen = inFrame.configLen;
    outFrame.bufLen = inFrame.bufLen;
    memcpy(outFrame.buffer, inFrame.buffer, inFrame.bufLen);
}

+ (void)setEnableReverb:(bool)bEnable
{
    if (g_enableReverb == bEnable)
        return;
    
    g_enableReverb = bEnable;
    [self releaseApi];
    
    AVE::ExtPrepSet set;
    set.bEncode = false;
    set.nChannel = 0;
    set.nSamples = 0;
    set.nSampleRate = 0;
    
    if (bEnable)
    {
        [ZegoLiveRoomApi setAudioPrep2:set dataCallback:prep2_func];
//        [ZegoLiveRoomApi setAudioPrep:&prep_func];
    }
    else
    {
        [ZegoLiveRoomApi setAudioPrep2:set dataCallback:nil];
        
//        [ZegoLiveRoomApi setAudioPrep:nil];
    }
}

+ (bool)reverbEnabled
{
    return g_enableReverb;
}

+ (void)setRecordTime:(bool)record
{
    if (g_recordTime == record)
        return;
    
    g_recordTime = record;
    [self setUsingExternalFilter:g_recordTime];
}

+ (bool)recordTime
{
    return g_recordTime;
}

+ (bool)useHeadSet
{
    return g_useHeadSet;
}

+ (void)setUsingInternationDomain:(bool)bUse
{
    if (g_useInternationDomain == bUse)
        return;
    
    g_useInternationDomain = bUse;
}

+ (bool)usingInternationDomain
{
    return g_useInternationDomain;
}

+ (void)setAppType:(ZegoAppType)type {
    if (g_appType == type)
        return;
    
    // 本地持久化
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:type forKey:kZegoDemoAppTypeKey];
    
    g_appType = type;
    
    [self releaseApi];
    
    // 临时兼容 SDK 的 Bug，立即初始化 api 对象
    if ([self api] == nil) {
        [self api];
    }
}

+ (ZegoAppType)appType {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSUInteger type = [ud integerForKey:kZegoDemoAppTypeKey];
    g_appType = (ZegoAppType)type;
    return (ZegoAppType)type;
}

#pragma mark - private

+ (void)setupVideoCaptureDevice
{

#if TARGET_OS_SIMULATOR
    g_useExternalCaptrue = YES;
    
    if (g_factory == nullptr) {
        g_factory = [[ZegoVideoCaptureFactory alloc] init];
        [ZegoLiveRoomApi setVideoCaptureFactory:g_factory];
    }
#else
    
     // try VideoCaptureFactoryDemo for camera
//     static __strong id<ZegoVideoCaptureFactory> g_factory = nullptr;

    /*
    g_useExternalCaptrue = YES;
    
     if (g_factory == nullptr)
     {
         g_factory = [[VideoCaptureFactoryDemo alloc] init];
         [ZegoLiveRoomApi setVideoCaptureFactory:g_factory];
     }
     */
#endif
}

+ (void)setupVideoFilter
{
    if (!g_useExternalFilter)
        return;
    
    if (g_filterFactory == nullptr)
        g_filterFactory = [[ZegoVideoFilterFactoryDemo alloc] init];
    
    [ZegoLiveRoomApi setVideoFilterFactory:g_filterFactory];
}

#warning 请开发者联系 ZEGO support 获取各自业务的 AppID 与 signKey
#warning Demo 默认使用 UDP 模式，请填充该模式下的 AppID 与 signKey
#warning AppID 填写样式示例：1234567890
#warning signKey 填写样式示例：{0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x01}
+ (uint32_t)appID
{
    switch ([self appType]) {
        case ZegoAppTypeCustom:
        {
            NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
            uint32_t appID = [[ud objectForKey:kZegoDemoAppIDKey] unsignedIntValue];
            
            if (appID != 0) {
                return appID;
            } else {
                return 0;
            }
        }
            break;
        case ZegoAppTypeUDP:
            return ;  // UDP版
            break;
        case ZegoAppTypeI18N:
            return 100;  // 国际版
            break;
    }
}

#warning 请开发者联系 ZEGO support 获取各自业务的 AppID 与 signKey
#warning Demo 默认使用 UDP 模式，请填充该模式下的 AppID 与 signKey
#warning AppID 填写样式示例：1234567890
#warning signKey 填写样式示例：{0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x01}
+ (NSData *)zegoAppSignFromServer
{
    //!! 规范用法：signKey 需要从 server 下发到 App，避免在 App 中存储，防止盗用

    ZegoAppType type = [self appType];
    
    if (type == ZegoAppTypeUDP)
    {
        Byte signkey[] = ;
        return [NSData dataWithBytes:signkey length:32];
    }
    else if (type == ZegoAppTypeI18N)
    {
        Byte signkey[] = {0x00};
        return [NSData dataWithBytes:signkey length:32];
    }
    else
    {
        // 自定义模式下从本地持久化文件中加载
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSString *appSign = [ud objectForKey:kZegoDemoAppSignKey];
        if (appSign) {
            return ConvertStringToSign(appSign);
        } else {
            return nil;
        }
    }
}

+ (NSString *)customAppSign {
    ZegoAppType type = [self appType];
    if (type == ZegoAppTypeCustom) {
        // 从本地持久化文件中加载
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSString *appSign = [ud objectForKey:kZegoDemoAppSignKey];
        return appSign;
    } else {
        return nil;
    }
}


+ (NSString *)getMyRoomID:(ZegoDemoRoomType)roomType
{
    switch (roomType) {
        case SinglePublisherRoom: // * 单主播
            return [NSString stringWithFormat:@"#d-%@", [ZegoSettings sharedInstance].userID];
        case MultiPublisherRoom: // * 连麦
            return [NSString stringWithFormat:@"#m-%@", [ZegoSettings sharedInstance].userID];
        case MixStreamRoom: // * 混流
            return [NSString stringWithFormat:@"#s-%@", [ZegoSettings sharedInstance].userID];
        case WerewolfRoom:
            return [NSString stringWithFormat:@"#w-%@", [ZegoSettings sharedInstance].userID];
        case WerewolfInTurnRoom:
        {
            return [NSString stringWithFormat:@"#i-%@", [ZegoSettings sharedInstance].userID];
        }
        default:
            return nil;
    }
}

+ (NSString *)getPublishStreamID
{
    NSString *userID = [[ZegoSettings sharedInstance] userID];
    unsigned long currentTime = (unsigned long)[[NSDate date] timeIntervalSince1970];
    return [NSString stringWithFormat:@"s-%@-%lu", userID, currentTime];
}

@end

Byte toByte(NSString* c)
{
    NSString *str = @"0123456789abcdef";
    Byte b = [str rangeOfString:c].location;
    return b;
}

NSData* ConvertStringToSign(NSString* strSign)
{
    if(strSign == nil || strSign.length == 0)
        return nil;
    strSign = [strSign lowercaseString];
    strSign = [strSign stringByReplacingOccurrencesOfString:@" " withString:@""];
    strSign = [strSign stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    NSArray* szStr = [strSign componentsSeparatedByString:@","];
    int nLen = (int)[szStr count];
    Byte szSign[32];
    for(int i = 0; i < nLen; i++)
    {
        NSString *strTmp = [szStr objectAtIndex:i];
        if(strTmp.length == 1)
            szSign[i] = toByte(strTmp);
        else
        {
            szSign[i] = toByte([strTmp substringWithRange:NSMakeRange(0, 1)]) << 4 | toByte([strTmp substringWithRange:NSMakeRange(1, 1)]);
        }
        NSLog(@"%x,", szSign[i]);
    }
    
    NSData *sign = [NSData dataWithBytes:szSign length:32];
    return sign;
}


#pragma mark - alpha support

@interface NSObject()
// * suppress warning
+ (void)setUseAlphaEnv:(id)useAlphaEnv;
@end

@implementation ZegoDemoHelper (Alpha)

+ (void)setUsingAlphaEnv:(bool)alphaEnv
{
    if ([ZegoLiveRoomApi respondsToSelector:@selector(setUseAlphaEnv:)])
    {
        if (g_useAlphaEnv != alphaEnv)
        {
            [self releaseApi];
        }
        
        g_useAlphaEnv = alphaEnv;
        [ZegoLiveRoomApi performSelector:@selector(setUseAlphaEnv:) withObject:@(alphaEnv)];
    }
}

@end



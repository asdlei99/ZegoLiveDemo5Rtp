// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from auto_config.djinni

#import <Foundation/Foundation.h>


@interface ZGResponseListener : NSObject

- (void)onResponse:(nonnull NSString *)response
         requestId:(int32_t)requestId;

- (void)onErrorResponse:(nonnull NSString *)error
              stateCode:(int32_t)stateCode
              requestId:(int32_t)requestId;

@end

//
//  XMPPNetworkReachability.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 23.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, XMPPNetworkReachabilityStatus) {
    XMPPNetworkReachabilityStatusUnknown = 0,
    XMPPNetworkReachabilityStatusNotReachable,
    XMPPNetworkReachabilityStatusReachableViaWiFi,
    XMPPNetworkReachabilityStatusReachableViaWWAN
};

@class XMPPNetworkReachability;

@protocol XMPPNetworkReachabilityDelegate <NSObject>
@optional
- (void)networkReachabilityDidChange:(XMPPNetworkReachability *)networkReachability;
@end

@interface XMPPNetworkReachability : NSObject

#pragma mark Life-cycle
- (instancetype)initWithQueue:(dispatch_queue_t)queue;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPNetworkReachabilityDelegate> delegate;

#pragma mark Manage Hostnames
@property (nonatomic, readonly) NSArray *hostnames;
- (void)addHostname:(NSString *)hostname;
- (void)removeHostname:(NSString *)hostname;
- (void)removeAllHostnames;

#pragma mark Reachability Status
- (XMPPNetworkReachabilityStatus)reachabilityStatusForHost:(NSString *)hostname;

@end

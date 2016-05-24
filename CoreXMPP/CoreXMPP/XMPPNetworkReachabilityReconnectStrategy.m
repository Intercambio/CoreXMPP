//
//  XMPPNetworkReachabilityReconnectStrategy.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>

#import "XMPPNetworkReachabilityReconnectStrategy.h"

typedef NS_ENUM(NSInteger, XMPPNetworkReachabilityReconnectStrategyStatus) {
    XMPPNetworkReachabilityReconnectStrategyStatusUnknown = 0,
    XMPPNetworkReachabilityReconnectStrategyStatusNotReachable,
    XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWiFi,
    XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWWAN
};

@interface XMPPNetworkReachabilityReconnectStrategy () {
    SCNetworkReachabilityRef _reachability;
}

@end

@implementation XMPPNetworkReachabilityReconnectStrategy

static void
XMPPNetworkReachabilityReconnectStrategyCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

#pragma mark Life-cycle

- (instancetype)initWithClient:(XMPPClient *)client hostname:(NSString *)hostname
{
    self = [super init];
    if (self) {
        _client = client;
        _hostname = hostname;
    }
    return self;
}

#pragma mark XMPPReconnectStrategy

- (NSDate *)nextConnectionAttempt
{
    return nil;
}

- (void)start
{
    if (_reachability == nil) {
        _reachability = SCNetworkReachabilityCreateWithName(NULL, [self.hostname UTF8String]);
        SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        SCNetworkReachabilitySetCallback(_reachability, XMPPNetworkReachabilityReconnectStrategyCallback, &context);
        SCNetworkReachabilitySetDispatchQueue(_reachability, dispatch_get_main_queue());
    }
}

- (void)stop
{
    if (_reachability) {
        CFRelease(_reachability);
        _reachability = nil;
    }
}

#pragma mark -

- (void)reacabilityFlags:(SCNetworkReachabilityFlags)flags didChangeForTarget:(SCNetworkReachabilityRef)target
{
    XMPPNetworkReachabilityReconnectStrategyStatus status = [self networkStatusForFlags:flags];
    switch (status) {
    case XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWiFi:
    case XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWWAN:
        [self.client connect];
        [self stop];
        break;

    default:
        break;
    }
}

- (XMPPNetworkReachabilityReconnectStrategyStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    // Base on Sample Code (Reachability) by Apple.

    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // The target host is not reachable.
        return XMPPNetworkReachabilityReconnectStrategyStatusNotReachable;
    }

    XMPPNetworkReachabilityReconnectStrategyStatus status = XMPPNetworkReachabilityReconnectStrategyStatusNotReachable;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {

        // If the target host is reachable and no connection is
        // required then we'll assume (for now) that you're on Wi-Fi...

        status = XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWiFi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {

        // ... and the connection is on-demand (or on-traffic) if the
        // calling application is using the CFSocketStream or higher APIs...

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {

            // ... and no [user] intervention is needed...

            status = XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWiFi;
        }
    }

#if TARGET_OS_IPHONE
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {

        // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.

        status = XMPPNetworkReachabilityReconnectStrategyStatusReachableViaWWAN;
    }
#endif

    return status;
}

static void
XMPPNetworkReachabilityReconnectStrategyCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    NSCAssert(info != NULL, @"info was NULL in XMPPNetworkReachabilityReconnectStrategy");
    NSCAssert([(__bridge XMPPNetworkReachabilityReconnectStrategy *)info isKindOfClass:[XMPPNetworkReachabilityReconnectStrategy class]], @"info was wrong class in XMPPNetworkReachabilityReconnectStrategy");

    XMPPNetworkReachabilityReconnectStrategy *strategy = (__bridge XMPPNetworkReachabilityReconnectStrategy *)info;
    [strategy reacabilityFlags:flags didChangeForTarget:target];
}

@end

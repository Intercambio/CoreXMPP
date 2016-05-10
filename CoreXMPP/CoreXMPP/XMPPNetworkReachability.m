//
//  XMPPNetworkReachability.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 23.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>

#import "XMPPNetworkReachability.h"

@interface XMPPNetworkReachability () {
    dispatch_queue_t _operationQueue;
    NSMutableDictionary *_reachabilityRefByHostname;
    NSMutableDictionary *_reachabilityFlagsByHostname;
}

@end

@implementation XMPPNetworkReachability

static void
XMPPNetworkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

+ (XMPPNetworkReachabilityStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    // Base on Sample Code (Reachability) by Apple.

    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // The target host is not reachable.
        return XMPPNetworkReachabilityStatusNotReachable;
    }

    XMPPNetworkReachabilityStatus status = XMPPNetworkReachabilityStatusNotReachable;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {

        // If the target host is reachable and no connection is
        // required then we'll assume (for now) that you're on Wi-Fi...

        status = XMPPNetworkReachabilityStatusReachableViaWiFi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {

        // ... and the connection is on-demand (or on-traffic) if the
        // calling application is using the CFSocketStream or higher APIs...

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {

            // ... and no [user] intervention is needed...

            status = XMPPNetworkReachabilityStatusReachableViaWiFi;
        }
    }

#if TARGET_OS_IPHONE
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {

        // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.

        status = XMPPNetworkReachabilityStatusReachableViaWWAN;
    }
#endif

    return status;
}

#pragma mark Life-cycle

- (instancetype)initWithQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self) {
        _operationQueue = queue ?: dispatch_get_main_queue();
        _reachabilityRefByHostname = [[NSMutableDictionary alloc] init];
        _reachabilityFlagsByHostname = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self removeAllHostnames];
}

#pragma mark Manage Hostnames

- (NSArray *)hostnames
{
    return [_reachabilityRefByHostname allKeys];
}

- (void)addHostname:(NSString *)hostname
{
    if ([_reachabilityRefByHostname valueForKey:hostname] == nil) {
        SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostname UTF8String]);
        if (reachability) {

            SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
            SCNetworkReachabilitySetCallback(reachability, XMPPNetworkReachabilityCallback, &context);
            SCNetworkReachabilitySetDispatchQueue(reachability, _operationQueue);

            [_reachabilityRefByHostname setObject:(__bridge id)(reachability) forKey:hostname];

            CFRelease(reachability);
        }
    }
}

- (void)removeHostname:(NSString *)hostname
{
    SCNetworkReachabilityRef reachability = (__bridge SCNetworkReachabilityRef)[_reachabilityRefByHostname valueForKey:hostname];
    if (reachability) {
        [_reachabilityRefByHostname removeObjectForKey:hostname];
    }
}

- (void)removeAllHostnames
{
    for (NSString *hostname in self.hostnames) {
        [self removeHostname:hostname];
    }
}

#pragma mark Reachability Status

- (XMPPNetworkReachabilityStatus)reachabilityStatusForHost:(NSString *)hostname
{
    NSNumber *_flags = [_reachabilityFlagsByHostname objectForKey:hostname];
    if (_flags) {
        return [[self class] networkStatusForFlags:(SCNetworkReachabilityFlags)[_flags integerValue]];
    } else {
        return XMPPNetworkReachabilityStatusUnknown;
    }
}

#pragma mark -

- (void)xmpp_updateReacabilityFlags:(SCNetworkReachabilityFlags)flags forTarget:(SCNetworkReachabilityRef)target
{
    __block NSString *hostname = nil;

    [_reachabilityRefByHostname enumerateKeysAndObjectsUsingBlock:^(NSString *key, id ref, BOOL *stop) {
        if (ref == (__bridge id)(target)) {
            hostname = key;
        }
    }];

    if (hostname) {

        XMPPNetworkReachabilityStatus oldStatus = [self reachabilityStatusForHost:hostname];
        XMPPNetworkReachabilityStatus newStatus = [[self class] networkStatusForFlags:flags];

        [_reachabilityFlagsByHostname setObject:@(flags) forKey:hostname];

        if (oldStatus != newStatus) {
            if ([self.delegate respondsToSelector:@selector(networkReachabilityDidChange:)]) {
                [self.delegate networkReachabilityDidChange:self];
            }
        }
    }
}

static void
XMPPNetworkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge XMPPNetworkReachability *)info isKindOfClass:[XMPPNetworkReachability class]], @"info was wrong class in ReachabilityCallback");

    XMPPNetworkReachability *reachability = (__bridge XMPPNetworkReachability *)info;
    [reachability xmpp_updateReacabilityFlags:flags forTarget:target];
}

@end

//
//  XMPPNetworkReachabilityReconnectStrategy.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
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

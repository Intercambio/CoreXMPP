//
//  XMPPClientReconnectStrategy.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>

#import "XMPPClient.h"
#import "XMPPClientReconnectStrategy.h"

NSString *const XMPPClientReconnectStrategyDidChangeNotification = @"XMPPClientReconnectStrategyDidChangeNotification";

typedef NS_ENUM(NSInteger, XMPPClientReconnectStrategyReachabilityStatus) {
    XMPPClientReconnectStrategyReachabilityStatusUnknown = 0,
    XMPPClientReconnectStrategyReachabilityStatusNotReachable,
    XMPPClientReconnectStrategyReachabilityStatusReachableViaWiFi,
    XMPPClientReconnectStrategyReachabilityStatusReachableViaWWAN
};

@interface XMPPClientReconnectStrategy () {
    dispatch_queue_t _operationQueue;
    NSTimer *_timer;
    SCNetworkReachabilityRef _reachability;
}

@end

@implementation XMPPClientReconnectStrategy

static void
XMPPClientReconnectStrategyReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

#pragma mark Life-cycle

- (instancetype)initWithClient:(XMPPClient *)client
{
    self = [super init];
    if (self) {
        _client = client;
        _minTimeInterval = 1.0;
        _maxTimeInterval = 60.0;
        _operationQueue = dispatch_queue_create("XMPPClientReconnectStrategy", DISPATCH_QUEUE_SERIAL);

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDidConnect:)
                                                     name:XMPPClientDidConnectNotification
                                                   object:client];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientDidDisconnect:)
                                                     name:XMPPClientDidDisconnectNotification
                                                   object:client];
    }
    return self;
}

- (void)dealloc
{
    [self xmpp_cancleReconnectTimer];
    [self xmpp_disableNetworkReachability];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Strategy

- (NSDate *)nextConnectionAttempt
{
    return _timer.fireDate;
}

#pragma mark Notification Handling

- (void)clientDidConnect:(NSNotification *)notification
{
    XMPPClient *client = notification.object;
    BOOL resumed = [notification.userInfo[XMPPClientResumedKey] boolValue];
    [self xmpp_clientDidConnect:client resumedStream:resumed];
}

- (void)clientDidDisconnect:(NSNotification *)notification
{
    XMPPClient *client = notification.object;
    NSError *error = notification.userInfo[XMPPClientErrorKey];
    if (error) {
        [self xmpp_client:client didFailWithError:error];
    } else {
        [self xmpp_clientDidDisconnect:client];
    }
}

#pragma mark -

- (void)xmpp_clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream
{
    [self xmpp_setType:XMPPClientReconnectStrategyNone];
    [self xmpp_cancleReconnectTimer];
    [self xmpp_disableNetworkReachability];
}

- (void)xmpp_clientDidDisconnect:(XMPPClient *)client
{
    [self.client connect];
    [self xmpp_setType:XMPPClientReconnectStrategyNone];
}

- (void)xmpp_client:(XMPPClient *)client didFailWithError:(NSError *)error
{
    if ([self xmpp_isReachabilityError:error]) {
        NSString *hostname = client.hostname;
        if (hostname) {
            [self xmpp_reconnectWhenHostIsReachable:hostname];
            [self xmpp_setType:XMPPClientReconnectStrategyNetworkReachability];
        } else {
            [self.client connect];
        }
    } else if ([self xmpp_isTemporalError:error]) {
        NSTimeInterval reconnectTimeInterval = [self xmpp_reconnectTimeInterval];
        if (reconnectTimeInterval > 0) {
            [self xmpp_reconnectAfterTimeInterval:reconnectTimeInterval];
            [self xmpp_setType:XMPPClientReconnectStrategyTemporal];
        } else {
            [self.client connect];
        }
    } else {
        [self.client connect];
    }
}

- (BOOL)xmpp_isTemporalError:(NSError *)error
{
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        switch (error.code) {
        case 57: // Socket is not connected
            return NO;

        default:
            break;
        }
    }

    return YES;
}

- (BOOL)xmpp_isReachabilityError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain]) {

        switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorCannotFindHost:
            return YES;

        default:
            break;
        }
    }

    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        return NO;
    }

    if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork]) {
        switch (error.code) {
        case kCFURLErrorNotConnectedToInternet:
        case kCFURLErrorDNSLookupFailed:
        case kCFURLErrorCannotFindHost:
            return YES;

        default:
            break;
        }
    }

    return NO;
}

- (NSTimeInterval)xmpp_reconnectTimeInterval
{
    return fmin(pow(2, self.client.numberOfConnectionAttempts) * self.minTimeInterval, self.maxTimeInterval);
}

- (void)xmpp_reconnectAfterTimeInterval:(NSTimeInterval)reconnectTimeInterval
{
    [_timer invalidate];
    _timer = nil;

    if (reconnectTimeInterval > 0) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:reconnectTimeInterval
                                                  target:self
                                                selector:@selector(xmpp_reconnectClientWithTimer:)
                                                userInfo:nil
                                                 repeats:NO];
    }
}

- (void)xmpp_reconnectClientWithTimer:(NSTimer *)timer
{
    [self xmpp_cancleReconnectTimer];
    [self.client connect];
}

- (void)xmpp_cancleReconnectTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)xmpp_reconnectWhenHostIsReachable:(NSString *)hostname
{
    if (_reachability) {
        CFRelease(_reachability);
        _reachability = nil;
    }

    if (hostname) {
        _reachability = SCNetworkReachabilityCreateWithName(NULL, [hostname UTF8String]);
        SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        SCNetworkReachabilitySetCallback(_reachability, XMPPClientReconnectStrategyReachabilityCallback, &context);
        SCNetworkReachabilitySetDispatchQueue(_reachability, _operationQueue);
    }
}

- (void)xmpp_disableNetworkReachability
{
    if (_reachability) {
        CFRelease(_reachability);
        _reachability = nil;
    }
}

- (void)xmpp_reacabilityFlags:(SCNetworkReachabilityFlags)flags didChangeForTarget:(SCNetworkReachabilityRef)target
{
    if ([self networkStatusForFlags:flags] != XMPPClientReconnectStrategyReachabilityStatusNotReachable) {
        [self xmpp_disableNetworkReachability];
        [self.client connect];
    }
}

- (XMPPClientReconnectStrategyReachabilityStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    // Base on Sample Code (Reachability) by Apple.

    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // The target host is not reachable.
        return XMPPClientReconnectStrategyReachabilityStatusNotReachable;
    }

    XMPPClientReconnectStrategyReachabilityStatus status = XMPPClientReconnectStrategyReachabilityStatusNotReachable;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {

        // If the target host is reachable and no connection is
        // required then we'll assume (for now) that you're on Wi-Fi...

        status = XMPPClientReconnectStrategyReachabilityStatusReachableViaWiFi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {

        // ... and the connection is on-demand (or on-traffic) if the
        // calling application is using the CFSocketStream or higher APIs...

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {

            // ... and no [user] intervention is needed...

            status = XMPPClientReconnectStrategyReachabilityStatusReachableViaWiFi;
        }
    }

#if TARGET_OS_IPHONE
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {

        // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.

        status = XMPPClientReconnectStrategyReachabilityStatusReachableViaWWAN;
    }
#endif

    return status;
}

- (void)xmpp_setType:(XMPPClientReconnectStrategyType)type
{
    if (_type != type) {
        _type = type;
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientReconnectStrategyDidChangeNotification
                                                            object:self];
    }
}

#pragma mark -

static void
XMPPClientReconnectStrategyReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    NSCAssert(info != NULL, @"info was NULL in XMPPClientReconnectStrategyReachabilityCallback");
    NSCAssert([(__bridge XMPPClientReconnectStrategy *)info isKindOfClass:[XMPPClientReconnectStrategy class]], @"info was wrong class in XMPPClientReconnectStrategyReachabilityCallback");

    XMPPClientReconnectStrategy *reachability = (__bridge XMPPClientReconnectStrategy *)info;
    [reachability xmpp_reacabilityFlags:flags didChangeForTarget:target];
}

@end

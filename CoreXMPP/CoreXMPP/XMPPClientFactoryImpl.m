//
//  XMPPClientFactoryImpl.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientFactoryImpl.h"
#import "NSError+ConnectivityErrorType.h"
#import "NSError+ConnectivityHostname.h"
#import "XMPPClient.h"
#import "XMPPImmediatelyReconnectStrategy.h"
#import "XMPPNetworkReachabilityReconnectStrategy.h"
#import "XMPPTemporalReconnectStrategy.h"

@implementation XMPPClientFactoryImpl

- (instancetype)init
{
    self = [super init];
    if (self) {
        _minReconnectTimeInterval = 1.0;
        _maxReconnectTimeInterval = 60.0;
    }
    return self;
}

#pragma mark Client

- (XMPPClient *)createClientToHost:(NSString *)hostname
                       withOptions:(NSDictionary *)options
                            stream:(XMPPStream *)stream
{
    return [[XMPPClient alloc] initWithHostname:hostname options:options stream:stream];
}

#pragma mark Reconnect Strategy

- (id<XMPPReconnectStrategy>)reconnectStrategyForClient:(XMPPClient *)client
                                              withError:(NSError *)error
                                       numberOfAttempts:(NSUInteger)numberOfAttempts
{
    XMPPConnectivityErrorType errorType = [error xmpp_ConnectivityErrorType];

    switch (errorType) {
    case XMPPConnectivityErrorTypeNone:
        return [[XMPPImmediatelyReconnectStrategy alloc] initWithClient:client];

    case XMPPConnectivityErrorTypeTemporal:
        return [[XMPPTemporalReconnectStrategy alloc] initWithClient:client
                                               reconnectTimeInterval:[self reconnectTimeIntervalWithNumberOfAttempts:numberOfAttempts]];

    case XMPPConnectivityErrorTypeNetworkReachability:
        return [[XMPPNetworkReachabilityReconnectStrategy alloc] initWithClient:client
                                                                       hostname:[error xmpp_connectivityHostname]];

    case XMPPConnectivityErrorTypePermanent:
    default:
        return nil;
    }
}

- (NSTimeInterval)reconnectTimeIntervalWithNumberOfAttempts:(NSUInteger)numberOfAttempts
{
    return fmin(pow(2, numberOfAttempts) * self.minReconnectTimeInterval, self.maxReconnectTimeInterval);
}

@end

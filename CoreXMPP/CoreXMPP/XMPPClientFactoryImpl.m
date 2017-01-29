//
//  XMPPClientFactoryImpl.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
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

//
//  XMPPAccountConnectivityImpl.m
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

#import "XMPPAccountConnectivityImpl.h"
#import "NSError+ConnectivityErrorType.h"
#import "XMPPReconnectStrategy.h"

@interface XMPPAccountConnectivityImpl ()
@property (nonatomic, readwrite) XMPPAccountConnectionState connectionState;
@property (nonatomic, readwrite) NSError *recentError;
@property (nonatomic, readwrite) NSUInteger numberOfAttempts;
@property (nonatomic, readwrite) id<XMPPReconnectStrategy> reconnectStrategy;
@end

@implementation XMPPAccountConnectivityImpl

@synthesize account = _account;

+ (NSSet *)keyPathsForValuesAffectingNextConnectionAttempt
{
    return [NSSet setWithObject:@"self.reconnectStrategy.nextConnectionAttempt"];
}

#pragma mark Life-cycle

- (instancetype)initWithAccount:(XMPPJID *)account
                         client:(XMPPClient *)client
{
    self = [super init];
    if (self) {
        _account = account;
        _client = client;
    }
    return self;
}

- (void)dealloc
{
    [self clearReconnectStrategy];
}

#pragma mark XMPPAccountInfo

- (NSDate *)nextConnectionAttempt
{
    return self.reconnectStrategy.nextConnectionAttempt;
}

#pragma mark XMPPAccountConnectivity

- (XMPPAccountConnectivityState)state
{
    return self.connectionState;
}

- (void)connect
{
    [self.client connect];
}

#pragma mark XMPPClientDelegate

- (void)client:(XMPPClient *)client didChangeState:(XMPPClientState)state
{
    switch (state) {
    case XMPPClientStateDisconnected:
        self.connectionState = XMPPAccountConnectionStateDisconnected;
        break;

    case XMPPClientStateConnecting:
    case XMPPClientStateEstablished:
    case XMPPClientStateNegotiating:
        self.connectionState = XMPPAccountConnectionStateConnecting;
        break;

    case XMPPClientStateConnected:
        self.connectionState = XMPPAccountConnectionStateConnected;
        break;

    case XMPPClientStateDisconnecting:
        self.connectionState = XMPPAccountConnectionStateDisconnecting;
        break;
    }

    [self postChangeNotification];
}

- (void)clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream
{
    self.recentError = nil;
    self.numberOfAttempts = 0;
    [self clearReconnectStrategy];

    [self postChangeNotification];
}

- (void)clientDidDisconnect:(XMPPClient *)client
{
    [self.client connect];

    [self postChangeNotification];
}

- (void)client:(XMPPClient *)client didFailWithError:(NSError *)error
{
    self.recentError = error;
    self.numberOfAttempts += 1;

    [self setupReconnectStrategy];

    [self postChangeNotification];
}

#pragma mark -

- (void)setupReconnectStrategy
{
    [self clearReconnectStrategy];
    self.reconnectStrategy = [self.delegate accountConnectivity:self
                                     reconnectStrategyForClient:self.client
                                                      withError:self.recentError
                                               numberOfAttempts:self.numberOfAttempts];
    [self.reconnectStrategy start];
}

- (void)clearReconnectStrategy
{
    [self.reconnectStrategy stop];
    self.reconnectStrategy = nil;
}

- (void)postChangeNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountConnectivityDidChangeNotification
                                                        object:self];

    if ([self.delegate respondsToSelector:@selector(accountConnectivityDidChange:)]) {
        [self.delegate accountConnectivityDidChange:self];
    }
}

@end

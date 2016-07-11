//
//  XMPPAccountConnectivityImpl.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
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

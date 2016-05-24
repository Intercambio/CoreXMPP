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
@property (nonatomic, readwrite) XMPPAccountConnectivityState state;
@property (nonatomic, readwrite) NSError *recentError;
@property (nonatomic, readwrite) NSUInteger numberOfAttempts;
@property (nonatomic, readwrite) id<XMPPReconnectStrategy> reconnectStrategy;
@end

@implementation XMPPAccountConnectivityImpl

@synthesize account = _account;
@synthesize shouldReconnect = _shouldReconnect;

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

#pragma mark XMPPAccountConnectivity

- (NSDate *)nextConnectionAttempt
{
    return self.reconnectStrategy.nextConnectionAttempt;
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
        self.state = XMPPAccountConnectivityStateDisconnected;
        break;

    case XMPPClientStateConnecting:
    case XMPPClientStateEstablished:
    case XMPPClientStateNegotiating:
        self.state = XMPPAccountConnectivityStateConnecting;
        break;

    case XMPPClientStateConnected:
        self.state = XMPPAccountConnectivityStateConnected;
        break;

    case XMPPClientStateDisconnecting:
        self.state = XMPPAccountConnectivityStateDisconnecting;
        break;
    }
}

- (void)clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream
{
    self.recentError = nil;
    self.numberOfAttempts = 0;
    [self clearReconnectStrategy];
}

- (void)clientDidDisconnect:(XMPPClient *)client
{
    if (self.shouldReconnect) {
        [self.client connect];
    }
}

- (void)client:(XMPPClient *)client didFailWithError:(NSError *)error
{
    self.recentError = error;
    self.numberOfAttempts += 1;

    if (self.shouldReconnect) {
        [self setupReconnectStrategy];
    }
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

@end

//
//  XMPPReconnectStrategy.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 18.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPReconnectStrategy.h"
#import "XMPPClient.h"
#import "XMPPReconnectStrategyState.h"

NSString *const XMPPReconnectStrategyDidChangeClientStateNotification = @"XMPPReconnectStrategyDidChangeClientStateNotification";
NSString *const XMPPReconnectStrategyClientKey = @"XMPPReconnectStrategyClientKey";

@interface XMPPReconnectStrategy () {
    dispatch_queue_t _operationQueue;
    NSMutableArray *_clients;
    NSMapTable *_clientStrategyTypes;
    NSMapTable *_clientTimers;
}

@end

@implementation XMPPReconnectStrategy

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPReconnectStrategy", DISPATCH_QUEUE_SERIAL);
        _clients = [[NSMutableArray alloc] init];
        _clientStrategyTypes = [NSMapTable weakToStrongObjectsMapTable];
        _clientTimers = [NSMapTable weakToStrongObjectsMapTable];
        _reconnectionTimeInterval = 1.0;
        _maxReconnectionTimeInterval = 60.0;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    for (NSTimer *timer in [[_clientTimers objectEnumerator] allObjects]) {
        [timer invalidate];
    }
}

#pragma mark Clients

- (NSArray *)clients
{
    __block NSArray *clients = nil;
    dispatch_sync(_operationQueue, ^{
        clients = [_clients copy];
    });
    return clients;
}

- (void)addClient:(XMPPClient *)client
{
    dispatch_async(_operationQueue, ^{

        if ([_clients containsObject:client] == NO) {
            
            [_clients addObject:client];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(clientDidConnect:)
                                                         name:XMPPClientDidConnectNotification
                                                       object:client];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(clientDidDisconnect:)
                                                         name:XMPPClientDidDisconnectNotification
                                                       object:client];
            
            if (client.state == XMPPClientStateDisconnected) {
                [client connect];
            }
        }
    });
}

- (void)removeClient:(XMPPClient *)client
{
    dispatch_async(_operationQueue, ^{
        
        [_clients removeObject:client];
        
        [self xmpp_setStrategyType:XMPPReconnectStrategyNone forClient:client];
        [self xmpp_setReconnectTimeInterval:0 forClient:client];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:nil
                                                      object:client];
    });
}

#pragma mark Reconnection Strategy

- (XMPPReconnectStrategyType)reconnectStrategyForClient:(XMPPClient *)client
{
    __block XMPPReconnectStrategyType strategyType = XMPPReconnectStrategyNone;
    dispatch_sync(_operationQueue, ^{
        strategyType = [self xmpp_strategyTypeForClient:client];
    });
    return strategyType;
}

- (NSDate *)nextConnectionAttemptForClient:(XMPPClient *)client
{
    __block NSDate *nextConnectionAttempt = nil;
    dispatch_sync(_operationQueue, ^{
        nextConnectionAttempt = [self xmpp_nextConnectionAttemptForClient:client];
    });
    return nextConnectionAttempt;
}

#pragma mark Notification Handling

- (void)clientDidConnect:(NSNotification *)notification
{
    dispatch_async(_operationQueue, ^{
        XMPPClient *client = notification.object;
        BOOL resumed = [notification.userInfo[XMPPClientResumedKey] boolValue];
        [self xmpp_clientDidConnect:client resumedStream:resumed];
    });
}

- (void)clientDidDisconnect:(NSNotification *)notification
{
    dispatch_async(_operationQueue, ^{
        XMPPClient *client = notification.object;
        NSError *error = notification.userInfo[XMPPClientErrorKey];
        if (error) {
            [self xmpp_client:client didFailWithError:error];
        } else {
            [self xmpp_clientDidDisconnect:client];
        }
    });
}

#pragma mark -

- (void)xmpp_clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream
{
    [self xmpp_resetReconnectStrategyForClient:client];
}

- (void)xmpp_clientDidDisconnect:(XMPPClient *)client
{
    [self xmpp_reconnectClientImmediately:client];
}

- (void)xmpp_client:(XMPPClient *)client didFailWithError:(NSError *)error
{
    NSTimeInterval nextReconnectTimeInterval = fmin(pow(2, client.numberOfConnectionAttempts) * self.reconnectionTimeInterval, self.maxReconnectionTimeInterval);
    
    [self xmpp_reconnectClient:client afterTimeinterval:nextReconnectTimeInterval];
}

- (void)xmpp_reconnectClientImmediately:(XMPPClient *)client
{
    [self xmpp_setStrategyType:XMPPReconnectStrategyNone forClient:client];
    [client connect];
}

- (void)xmpp_reconnectClient:(XMPPClient *)client afterTimeinterval:(NSTimeInterval)timeInterval
{
    [self xmpp_setReconnectTimeInterval:timeInterval forClient:client];
    [self xmpp_setStrategyType:XMPPReconnectStrategyTimeout forClient:client];
}

- (void)xmpp_resetReconnectStrategyForClient:(XMPPClient *)client
{
    [self xmpp_setStrategyType:XMPPReconnectStrategyNone forClient:client];
    [self xmpp_setReconnectTimeInterval:0 forClient:client];
}

- (XMPPReconnectStrategyType)xmpp_strategyTypeForClient:(XMPPClient *)client
{
    return [[_clientStrategyTypes objectForKey:client] integerValue];
}

- (void)xmpp_setStrategyType:(XMPPReconnectStrategyType)strategyType forClient:(XMPPClient *)client
{
    if (strategyType == XMPPReconnectStrategyNone) {
        [_clientStrategyTypes removeObjectForKey:client];
    } else {
        [_clientStrategyTypes setObject:@(strategyType) forKey:client];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{XMPPReconnectStrategyClientKey: client};
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPReconnectStrategyDidChangeClientStateNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

- (NSDate *)xmpp_nextConnectionAttemptForClient:(XMPPClient *)client
{
    NSTimer *timer = [_clientTimers objectForKey:client];
    return timer.fireDate;
}

- (void)xmpp_setReconnectTimeInterval:(NSTimeInterval)timeInterval forClient:(XMPPClient *)client
{
    NSTimer *timer = [_clientTimers objectForKey:client];
    [timer invalidate];
    
    if (timeInterval > 0) {
        NSTimer *newTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                             target:self
                                                           selector:@selector(xmpp_reconnectClientForTimer:)
                                                           userInfo:client
                                                            repeats:NO];
        [_clientTimers setObject:newTimer forKey:client];
    } else {
        [_clientTimers removeObjectForKey:client];
    }
}

- (void)xmpp_reconnectClientForTimer:(NSTimer *)timer
{
    dispatch_async(_operationQueue, ^{
        XMPPClient *client = timer.userInfo;
        [timer invalidate];
        if (client) {
            [client connect];
        }
    });
}

@end

//
//  XMPPReconnectStrategy.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 18.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPClient;

typedef NS_ENUM(NSUInteger, XMPPReconnectStrategyType) {
    XMPPReconnectStrategyNone,
    XMPPReconnectStrategyTimeout,
    XMPPReconnectStrategyNetwork
};

extern NSString *const XMPPReconnectStrategyDidChangeClientStateNotification;
extern NSString *const XMPPReconnectStrategyClientKey;

@interface XMPPReconnectStrategy : NSObject

#pragma mark Strategy Parameters
@property (nonatomic, assign) NSTimeInterval reconnectionTimeInterval;
@property (nonatomic, assign) NSTimeInterval maxReconnectionTimeInterval;

#pragma mark Clients
@property (nonatomic, readonly) NSArray *clients;
- (void)addClient:(XMPPClient *)client;
- (void)removeClient:(XMPPClient *)client;

#pragma mark Reconnection Strategy
- (XMPPReconnectStrategyType)reconnectStrategyForClient:(XMPPClient *)client;
- (NSDate *)nextConnectionAttemptForClient:(XMPPClient *)client;

@end

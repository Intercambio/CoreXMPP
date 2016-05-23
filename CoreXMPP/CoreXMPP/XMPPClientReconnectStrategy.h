//
//  XMPPClientReconnectStrategy.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPClient;

extern NSString *const XMPPClientReconnectStrategyDidChangeNotification;

typedef NS_ENUM(NSUInteger, XMPPClientReconnectStrategyType) {
    XMPPClientReconnectStrategyNone = 0,
    XMPPClientReconnectStrategyTemporal,
    XMPPClientReconnectStrategyNetworkReachability
};

@interface XMPPClientReconnectStrategy : NSObject

#pragma mark Life-cycle
- (instancetype)initWithClient:(XMPPClient *)client;

#pragma mark Client
@property (nonatomic, readonly) XMPPClient *client;

#pragma mark Parameters
@property (nonatomic, assign) NSTimeInterval minTimeInterval;
@property (nonatomic, assign) NSTimeInterval maxTimeInterval;

#pragma mark Strategy
@property (nonatomic, readonly) XMPPClientReconnectStrategyType type;
@property (nonatomic, readonly) NSDate *nextConnectionAttempt;

@end

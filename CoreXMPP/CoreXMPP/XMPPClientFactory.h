//
//  XMPPClientFactory.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPReconnectStrategy.h"

@class XMPPClient;
@class XMPPStream;

@interface XMPPClientFactory : NSObject

#pragma mark Client
- (XMPPClient *)createClientToHost:(NSString *)hostname
                       withOptions:(NSDictionary *)options
                            stream:(XMPPStream *)stream;

#pragma mark Reconnect Strategy
@property (nonatomic, assign) NSTimeInterval minReconnectTimeInterval; // default 1.0
@property (nonatomic, assign) NSTimeInterval maxReconnectTimeInterval; // default 60.0

- (id<XMPPReconnectStrategy>)reconnectStrategyForClient:(XMPPClient *)client
                                              withError:(NSError *)error
                                       numberOfAttempts:(NSUInteger)numberOfAttempts;

@end

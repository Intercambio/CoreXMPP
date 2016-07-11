//
//  XMPPClientFactory.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 01.07.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClient.h"
#import "XMPPReconnectStrategy.h"
#import "XMPPStream.h"
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(ClientFactory)
@protocol XMPPClientFactory <NSObject>

- (nonnull XMPPClient *)createClientToHost:(nonnull NSString *)hostname
                               withOptions:(nullable NSDictionary<NSString *, id> *)options
                                    stream:(nullable XMPPStream *)stream NS_SWIFT_NAME(createClient(hostname:options:stream:));

- (nullable id<XMPPReconnectStrategy>)reconnectStrategyForClient:(nonnull XMPPClient *)client
                                                       withError:(nullable NSError *)error
                                                numberOfAttempts:(NSUInteger)numberOfAttempts NS_SWIFT_NAME(reconnectStrategy(client:error:numberOfAttempts:));

@end

//
//  XMPPClientFactoryStub.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientFactoryStub.h"

@implementation XMPPClientFactoryStub

- (XMPPClient *)createClientToHost:(NSString *)hostname
                       withOptions:(NSDictionary *)options
                            stream:(XMPPStream *)stream
{
    return [[XMPPClient alloc] initWithHostname:hostname
                                        options:options
                                         stream:self.stream];
}

- (id<XMPPReconnectStrategy>)reconnectStrategyForClient:(XMPPClient *)client withError:(NSError *)error numberOfAttempts:(NSUInteger)numberOfAttempts
{
    return nil;
}

@end

//
//  XMPPImmediatelyReconnectStrategy.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPImmediatelyReconnectStrategy.h"

@implementation XMPPImmediatelyReconnectStrategy

#pragma mark Life-cycle

- (instancetype)initWithClient:(XMPPClient *)client
{
    self = [super init];
    if (self) {
        _client = client;
    }
    return self;
}

#pragma mark XMPPReconnectStrategy

- (NSDate *)nextConnectionAttempt
{
    return nil;
}

- (void)start
{
    [self.client connect];
}

- (void)stop
{
}

@end

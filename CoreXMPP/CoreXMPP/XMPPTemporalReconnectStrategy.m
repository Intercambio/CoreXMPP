//
//  XMPPTemporalReconnectStrategy.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTemporalReconnectStrategy.h"

@interface XMPPTemporalReconnectStrategy () {
    NSTimer *_timer;
}

@end

@implementation XMPPTemporalReconnectStrategy

#pragma mark Life-cycle

- (instancetype)initWithClient:(XMPPClient *)client reconnectTimeInterval:(NSTimeInterval)reconnectTimeInterval
{
    self = [super init];
    if (self) {
        _client = client;
        _reconnectTimeInterval = reconnectTimeInterval;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark XMPPReconnectStrategy

- (NSDate *)nextConnectionAttempt
{
    return _timer.fireDate;
}

- (void)start
{
    if (_timer == nil) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:self.reconnectTimeInterval
                                                  target:self
                                                selector:@selector(connect:)
                                                userInfo:nil
                                                 repeats:NO];
    }
}

- (void)stop
{
    [_timer invalidate];
    _timer = nil;
}

#pragma mark -

- (void)connect:(NSTimer *)timer
{
    [self.client connect];
    [self stop];
}

@end

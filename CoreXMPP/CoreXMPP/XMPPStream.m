//
//  XMPPStream.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStream.h"

NSString *const XMPPStreamErrorDomain = @"XMPPStreamErrorDomain";

@implementation XMPPStream

#pragma mark Life-cycle

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _hostname = [hostname copy];
        _options = [options copy];
    }
    return self;
}

#pragma mark State

- (XMPPStreamState)state
{
    return XMPPStreamStateClosed;
}

#pragma mark Managing Stream

- (void)open
{
}

- (void)reopen
{
}

- (void)close
{
}

- (void)sendElement:(PXElement *)element
{
}

@end

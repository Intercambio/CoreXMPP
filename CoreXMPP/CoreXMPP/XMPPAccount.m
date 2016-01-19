//
//  XMPPAccount.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPJID.h"

#import "XMPPAccount.h"
#import "XMPPAccount+Private.h"

@implementation XMPPAccount

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[XMPPAccount class]]) {
        return [self.JID isEqual:[(XMPPAccount *)object JID]];
    }
    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<XMPPAccount: 0x100326e90 (JID: %@, service manager: %p)>", _JID, _serviceManger];
}

@end

@implementation XMPPAccount (Private)

- (instancetype)initWithJID:(XMPPJID *)JID
             serviceManager:(XMPPServiceManager *)serviceManager
{
    self = [super init];
    if (self) {
        _JID = JID;
        _serviceManger = serviceManager;
        _options = @{};
    }
    return self;
}

- (void)setOptions:(NSDictionary *)options
{
    _options = [options copy] ?: @{};
}

- (void)setSuspended:(BOOL)suspended
{
    _suspended = suspended;
}

- (void)setConnected:(BOOL)connected
{
    _connected = connected;
}

@end

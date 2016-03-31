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

NSString * const XMPPAccountDidChangeNotification = @"XMPPAccountDidChangeNotification";

@interface XMPPAccount () {
    XMPPKeyChainService *_keyChain;
}

@end

@implementation XMPPAccount

- (void)setPassword:(NSString *)password
{
    [_keyChain setPassword:password forIdentityWithJID:_JID];
}

- (NSString *)password
{
    return [_keyChain passwordForIdentityWithJID:_JID];
}

- (BOOL)connected
{
    return _clientState == XMPPClientStateConnected;
}

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
                   keyChain:(XMPPKeyChainService *)keyChain
{
    self = [super init];
    if (self) {
        _JID = JID;
        _serviceManger = serviceManager;
        _keyChain = keyChain;
        _options = @{};
    }
    return self;
}

- (XMPPKeyChainService *)keyChain
{
    return _keyChain;
}

- (void)setOptions:(NSDictionary *)options
{
    _options = [options copy] ?: @{};
    [self postChangeNotification];
}

- (void)setSuspended:(BOOL)suspended
{
    _suspended = suspended;
    [self postChangeNotification];
}

- (void)setClientState:(XMPPClientState)clientState
{
    _clientState = clientState;
    [self postChangeNotification];
}

- (void)setNumberOfConnectionAttempts:(NSUInteger)numberOfConnectionAttempts
{
    _numberOfConnectionAttempts = numberOfConnectionAttempts;
    [self postChangeNotification];
}

- (void)setNextConnectionAttempt:(NSDate *)nextConnectionAttempt
{
    _nextConnectionAttempt = nextConnectionAttempt;
    [self postChangeNotification];
}

- (void)setNeedsReachabilityChange:(BOOL)needsReachabilityChange
{
    _needsReachabilityChange = needsReachabilityChange;
    [self postChangeNotification];
}

- (void)setRecentError:(NSError *)recentError
{
    _recentError = recentError;
    [self postChangeNotification];
}

- (void)postChangeNotification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountDidChangeNotification
                                                            object:self];
    });
}

@end

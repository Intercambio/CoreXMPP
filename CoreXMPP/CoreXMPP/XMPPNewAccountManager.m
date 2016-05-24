//
//  XMPPNewAccountManager.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPNewAccountManager.h"
#import "XMPPClient.h"
#import "XMPPError.h"

@interface XMPPNewAccountManager () {
    XMPPClientFactory *_clientFactory;
    NSMutableDictionary *_clientsByAccount;
}

@end

@implementation XMPPNewAccountManager

#pragma mark Life-cycle

- (instancetype)initWithDispatcher:(XMPPDispatcher *)dispatcher
{
    return [self initWithDispatcher:dispatcher
                      clientFactory:nil];
}

- (instancetype)initWithDispatcher:(XMPPDispatcher *)dispatcher
                     clientFactory:(XMPPClientFactory *)clientFactory
{
    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _clientFactory = clientFactory ?: [[XMPPClientFactory alloc] init];
        _clientsByAccount = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark Managing Accounts

- (NSArray *)accounts
{
    return [_clientsByAccount allKeys];
}

- (BOOL)addAccount:(XMPPJID *)account
       withOptions:(NSDictionary *)options
             error:(NSError **)error
{
    if ([_clientsByAccount objectForKey:account]) {
        if (error) {
            *error = [NSError errorWithDomain:XMPPErrorDomain
                                         code:XMPPErrorCodeAccountExists
                                     userInfo:@{}];
        }
        return NO;
    } else {
        XMPPClient *client = [_clientFactory createClientToHost:account.host
                                                    withOptions:options
                                                         stream:nil];
        [_clientsByAccount setObject:client forKey:account];

        client.connectionDelegate = _dispatcher;
        [_dispatcher setConnection:client forJID:account];

        client.SASLContext = account;
        client.SASLDelegate = self.SASLDelegate;
        client.SASLDelegateQueue = dispatch_get_main_queue();

        return YES;
    }
}

- (void)updateOptions:(NSDictionary *)options
           forAccount:(XMPPJID *)account
{
    XMPPClient *client = [_clientsByAccount objectForKey:account];
    [client updateOptions:options];
}

- (void)removeAccount:(XMPPJID *)account
{
    [_clientsByAccount removeObjectForKey:account];
}

@end

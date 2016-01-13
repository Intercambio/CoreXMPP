//
//  XMPPServiceManager.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPWebsocketStream.h"
#import "XMPPClient.h"
#import "XMPPAccount.h"
#import "XMPPServiceManager.h"

NSString *const XMPPServiceManagerDidResumeAccountNotification = @"XMPPServiceManagerDidResumeAccountNotification";
NSString *const XMPPServiceManagerDidSuspendAccountNotification = @"XMPPServiceManagerDidSuspendAccountNotification";
NSString *const XMPPServiceManagerDidConnectAccountNotification = @"XMPPServiceManagerDidConnectAccountNotification";
NSString *const XMPPServiceManagerDidDisconnectAccountNotification = @"XMPPServiceManagerDidDisconnectAccountNotification";

NSString *const XMPPServiceManagerAccountKey = @"XMPPServiceManagerAccountKey";

@interface XMPPServiceManager () <XMPPClientDelegate> {
    dispatch_queue_t _operationQueue;
    NSMapTable *_accounts;
}

@end

@implementation XMPPServiceManager

#pragma mark Life-cycle

- (instancetype)initWithOptions:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPServiceManager", DISPATCH_QUEUE_SERIAL);
        _accounts = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}

#pragma mark Managing Accounts

- (NSArray *)accounts
{
    __block NSArray *accounts = nil;
    dispatch_sync(_operationQueue, ^{
        accounts = [[_accounts keyEnumerator] allObjects];
    });
    return accounts;
}

- (XMPPAccount *)accountWithJID:(NSString *)jid
{
    __block XMPPAccount *account = nil;
    dispatch_sync(_operationQueue, ^{

        // Validate JID

        for (XMPPAccount *a in _accounts) {
            if ([a.JID isEqualToString:jid]) {
                account = a;
                break;
            }
        }

        if (account == nil) {

            account = [[XMPPAccount alloc] initWithJID:jid];
            account.suspended = YES;

            NSString *hostname = @"localhost";
            NSDictionary *options = @{ XMPPWebsocketStreamURLKey : [NSURL URLWithString:@"ws://localhost:5280/xmpp"] };
            XMPPClient *client = [[XMPPClient alloc] initWithHostname:hostname
                                                              options:options];
            client.delegateQueue = _operationQueue;
            client.delegate = self;
            client.SASLDelegate = self.SASLDelegate;
            client.SASLDelegateQueue = dispatch_get_main_queue();
            client.SASLContext = account;

            [_accounts setObject:client forKey:account];
        }
    });
    return account;
}

- (void)removeAccount:(XMPPAccount *)account
{
    dispatch_sync(_operationQueue, ^{
        XMPPClient *client = [_accounts objectForKey:account];
        if (client) {
            [self xmpp_suspendAccounts:@[account]];
            [_accounts removeObjectForKey:account];
        }
    });
}

- (void)suspendAccount:(XMPPAccount *)account
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_suspendAccounts:@[account]];
    });
}

- (void)resumeAccount:(XMPPAccount *)account
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_resumeAccounts:@[account]];
    });
}

- (void)suspendAllAccounts
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_suspendAccounts:[[_accounts keyEnumerator] allObjects]];
    });
}

- (void)resumeAllAccounts
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_resumeAccounts:[[_accounts keyEnumerator] allObjects]];
    });
}

#pragma mark -

- (void)xmpp_suspendAccounts:(NSArray *)accounts
{
    for (XMPPAccount *account in accounts) {
        XMPPClient *client = [_accounts objectForKey:account];
        if (client) {
            if (account.suspended == NO) {
                account.suspended = YES;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidSuspendAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPServiceManagerAccountKey : account}];
                });
                
                if (client.state == XMPPClientStateEstablished) {
                    [client disconnect];
                }
            }
        }
    }
}

- (void)xmpp_resumeAccounts:(NSArray *)accounts
{
    for (XMPPAccount *account in accounts) {
        XMPPClient *client = [_accounts objectForKey:account];
        if (client) {
            if (account.suspended) {
                account.suspended = NO;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidResumeAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPServiceManagerAccountKey : account}];
                });
                
                if (client.state == XMPPClientStateDisconnected) {
                    [client connect];
                }
            }
        }
    }
}

#pragma mark XMPPClientDelegate (called on operation queue)

- (void)clientDidConnect:(XMPPClient *)client
{
    XMPPAccount *account = nil;
    for (XMPPAccount *a in _accounts) {
        if ([_accounts objectForKey:a] == client) {
            account = a;
            break;
        }
    }

    if (account) {
        account.connected = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidConnectAccountNotification
                                                                object:self
                                                              userInfo:@{XMPPServiceManagerAccountKey : account}];

        });
    }
}

- (void)clientDidDisconnect:(XMPPClient *)client
{
    XMPPAccount *account = nil;
    for (XMPPAccount *a in _accounts) {
        if ([_accounts objectForKey:a] == client) {
            account = a;
            break;
        }
    }
    
    if (account) {
        account.connected = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidDisconnectAccountNotification
                                                                object:self
                                                              userInfo:@{XMPPServiceManagerAccountKey : account}];
            
        });
    }
}

@end

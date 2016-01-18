//
//  XMPPServiceManager.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarn;
#endif

#import "XMPPWebsocketStream.h"
#import "XMPPClient.h"
#import "XMPPAccount.h"
#import "XMPPAccount+Private.h"
#import "XMPPServiceManager.h"

NSString *const XMPPServiceManagerDidResumeAccountNotification = @"XMPPServiceManagerDidResumeAccountNotification";
NSString *const XMPPServiceManagerDidSuspendAccountNotification = @"XMPPServiceManagerDidSuspendAccountNotification";
NSString *const XMPPServiceManagerDidConnectAccountNotification = @"XMPPServiceManagerDidConnectAccountNotification";
NSString *const XMPPServiceManagerDidDisconnectAccountNotification = @"XMPPServiceManagerDidDisconnectAccountNotification";

NSString *const XMPPServiceManagerAccountKey = @"XMPPServiceManagerAccountKey";

NSString *const XMPPServiceManagerOptionClientFactoryCallbackKey = @"XMPPServiceManagerOptionClientFactoryCallbackKey";

@interface XMPPServiceManager () <XMPPClientDelegate> {
    dispatch_queue_t _operationQueue;
    BOOL _suspended;
    NSMutableArray *_accounts;
    NSMapTable *_clients;
}

@end

@implementation XMPPServiceManager

#pragma mark Life-cycle

- (instancetype)initWithOptions:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _options = options;
        _operationQueue = dispatch_queue_create("XMPPServiceManager", DISPATCH_QUEUE_SERIAL);
        _clients = [NSMapTable strongToStrongObjectsMapTable];
        _accounts = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark Managing Service Manager

- (BOOL)isSuspended
{
    __block BOOL suspended;
    dispatch_sync(_operationQueue, ^{
        suspended = _suspended;
    });
    return suspended;
}

- (void)suspend
{
    dispatch_sync(_operationQueue, ^{
        [self xmpp_suspend];
    });
}

- (void)resume
{
    dispatch_sync(_operationQueue, ^{
        [self xmpp_resume];
    });
}

#pragma mark Managing Accounts

- (NSArray *)accounts
{
    __block NSArray *accounts = nil;
    dispatch_sync(_operationQueue, ^{
        accounts = [self xmpp_accounts];
    });
    return accounts;
}

- (XMPPAccount *)accountWithJID:(NSString *)jid
{
    __block XMPPAccount *account = nil;
    dispatch_sync(_operationQueue, ^{

        // TODO: Validate JID

        account = [self xmpp_accountWithJID:jid];
        if (account == nil) {
            account = [self xmpp_createAccountWithJID:jid];
        }

        if (_suspended == NO) {
            XMPPClient *client = [self xmpp_clientForAccount:account];
            if (client == nil) {
                client = [self xmpp_createClientForAccount:account];
            }
        }
    });
    return account;
}

- (void)removeAccount:(XMPPAccount *)account
{
    dispatch_sync(_operationQueue, ^{
        XMPPClient *client = [_clients objectForKey:account];
        if (client) {
            [self xmpp_suspendAccounts:@[ account ]];
            [self xmpp_removeAccount:account];
        }
    });
}

- (void)suspendAccount:(XMPPAccount *)account
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_suspendAccounts:@[ account ]];
    });
}

- (void)resumeAccount:(XMPPAccount *)account
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_resumeAccounts:@[ account ]];
    });
}

- (void)suspendAllAccounts
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_suspendAccounts:[self xmpp_accounts]];
    });
}

- (void)resumeAllAccounts
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_resumeAccounts:[self xmpp_accounts]];
    });
}

#pragma mark -

#pragma mark Accounts

- (NSArray *)xmpp_accounts
{
    return [_accounts copy];
}

- (XMPPAccount *)xmpp_accountWithJID:(NSString *)JID
{
    for (XMPPAccount *account in _accounts) {
        if ([account.JID isEqualToString:JID]) {
            return account;
        }
    }
    return nil;
}

- (XMPPAccount *)xmpp_createAccountWithJID:(NSString *)JID
{
    XMPPAccount *account = [[XMPPAccount alloc] initWithJID:JID serviceManager:self];
    account.suspended = YES;
    account.connected = NO;
    [_accounts addObject:account];
    return account;
}

- (void)xmpp_removeAccount:(XMPPAccount *)account
{
    [self xmpp_removeClientForAccount:account];
    [_accounts removeObject:account];
}

#pragma mark Clients

- (NSArray *)xmpp_clients
{
    return [[_clients objectEnumerator] allObjects];
}

- (XMPPAccount *)xmpp_accountForClient:(XMPPClient *)client
{
    XMPPAccount *account = nil;
    for (XMPPAccount *a in _clients) {
        if ([_clients objectForKey:a] == client) {
            account = a;
            break;
        }
    }
    return account;
}

- (XMPPClient *)xmpp_clientForAccount:(XMPPAccount *)account
{
    XMPPClient *client = [_clients objectForKey:account];
    return client;
}

- (XMPPClient *)xmpp_createClientForAccount:(XMPPAccount *)account
{
    XMPPClient *client = nil;

    XMPPServiceManagerClientFactoryCallback callback = self.options[XMPPServiceManagerOptionClientFactoryCallbackKey];
    if (callback) {
        client = callback(account, self.options);
    }

    if (client == nil) {
        NSString *hostname = @"localhost";
        NSDictionary *options = @{};
        client = [[XMPPClient alloc] initWithHostname:hostname
                                              options:options];
    }

    client.delegateQueue = _operationQueue;
    client.delegate = self;
    client.SASLDelegate = self.SASLDelegate;
    client.SASLDelegateQueue = dispatch_get_main_queue();
    client.SASLContext = account;

    [_clients setObject:client forKey:account];

    return client;
}

- (void)xmpp_removeClientForAccount:(XMPPAccount *)account
{
    XMPPClient *client = [_clients objectForKey:account];
    client.delegate = nil;
    client.delegateQueue = nil;
    account.connected = NO;
    [_clients removeObjectForKey:account];
}

#pragma mark Suspend & Resume

- (void)xmpp_suspend
{
    for (XMPPAccount *account in [self xmpp_accounts]) {
        [self xmpp_removeClientForAccount:account];
    }
    _suspended = YES;

    DDLogInfo(@"Did suspend service manager: %@", self);
}

- (void)xmpp_resume
{
    for (XMPPAccount *account in [self xmpp_accounts]) {
        if (account.suspended == NO) {
            XMPPClient *client = [self xmpp_clientForAccount:account];
            if (client == nil) {
                client = [self xmpp_createClientForAccount:account];
            }
            [client connect];
        }
    }
    _suspended = NO;

    DDLogInfo(@"Did resume service manager: %@", self);
}

- (void)xmpp_suspendAccounts:(NSArray *)accounts
{
    for (XMPPAccount *account in accounts) {
        XMPPClient *client = [self xmpp_clientForAccount:account];
        if (client) {
            if (account.suspended == NO) {
                account.suspended = YES;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidSuspendAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPServiceManagerAccountKey : account}];
                });

                DDLogInfo(@"Did suspend account: %@", account);

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
        XMPPClient *client = [self xmpp_clientForAccount:account];
        if (client) {
            if (account.suspended) {
                account.suspended = NO;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidResumeAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPServiceManagerAccountKey : account}];
                });

                DDLogInfo(@"Did resume account: %@", account);

                if (client.state == XMPPClientStateDisconnected) {
                    [client connect];
                }
            }
        }
    }
}

#pragma mark -
#pragma mark XMPPClientDelegate (called on operation queue)

- (void)clientDidConnect:(XMPPClient *)client
{
    XMPPAccount *account = [self xmpp_accountForClient:client];

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
    XMPPAccount *account = [self xmpp_accountForClient:client];
    if (account) {

        account.connected = NO;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidDisconnectAccountNotification
                                                                object:self
                                                              userInfo:@{XMPPServiceManagerAccountKey : account}];

        });

        if (account.suspended == NO) {
            [client connect];
        }
    }
}

- (void)client:(XMPPClient *)client didFailToNegotiateFeature:(XMPPStreamFeature *)feature withError:(NSError *)error
{
    __unused XMPPAccount *account = [self xmpp_accountForClient:client];
}

- (void)client:(XMPPClient *)client didFailWithError:(NSError *)error
{
    XMPPAccount *account = [self xmpp_accountForClient:client];
    if (account) {

        account.connected = NO;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidDisconnectAccountNotification
                                                                object:self
                                                              userInfo:@{XMPPServiceManagerAccountKey : account}];

        });

        if (account.suspended == NO) {
            DDLogInfo(@"Will reconnect client: %@", client);
            [client connect];
        }
    }
}

@end

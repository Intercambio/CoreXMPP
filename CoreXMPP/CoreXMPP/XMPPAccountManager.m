//
//  XMPPAccountManager.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPAccount+Private.h"
#import "XMPPAccount.h"
#import "XMPPAccountManager.h"
#import "XMPPClient.h"
#import "XMPPClientFactory.h"
#import "XMPPDispatcher.h"
#import "XMPPError.h"
#import "XMPPJID.h"
#import "XMPPKeyChainItemAttributes.h"
#import "XMPPKeyChainService.h"
#import "XMPPNetworkReachability.h"
#import "XMPPWebsocketStream.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPAccountManagerDidAddAccountNotification = @"XMPPAccountManagerDidAddAccountNotification";
NSString *const XMPPAccountManagerDidRemoveAccountNotification = @"XMPPAccountManagerDidRemoveAccountNotification";
NSString *const XMPPAccountManagerDidResumeAccountNotification = @"XMPPAccountManagerDidResumeAccountNotification";
NSString *const XMPPAccountManagerDidSuspendAccountNotification = @"XMPPAccountManagerDidSuspendAccountNotification";
NSString *const XMPPAccountManagerDidConnectAccountNotification = @"XMPPAccountManagerDidConnectAccountNotification";
NSString *const XMPPAccountManagerDidDisconnectAccountNotification = @"XMPPAccountManagerDidDisconnectAccountNotification";
NSString *const XMPPAccountManagerConnectionDidFailNotification = @"XMPPAccountManagerConnectionDidFailNotification";

NSString *const XMPPAccountManagerAccountKey = @"XMPPAccountManagerAccountKey";
NSString *const XMPPAccountManagerResumedKey = @"XMPPAccountManagerResumedKey";

NSString *const XMPPAccountManagerOptionClientFactoryCallbackKey = @"XMPPAccountManagerOptionClientFactoryCallbackKey";
NSString *const XMPPAccountManagerOptionsKeyChainServiceKey = @"XMPPAccountManagerOptionsKeyChainServiceKey";

@interface XMPPAccountManager () <XMPPClientDelegate, XMPPNetworkReachabilityDelegate> {
    dispatch_queue_t _operationQueue;
    XMPPKeyChainService *_keyChain;
    NSMutableArray *_accounts;
    NSMapTable *_clientsByAccount;
    NSMapTable *_networkReachabilitiesByClient;
    XMPPDispatcher *_dispatcher;
    NSMutableArray *_modules;
    XMPPClientFactory *_clientFactory;
}

@end

@implementation XMPPAccountManager

+ (BOOL)shouldReconnectImmediately:(NSError *)error
{
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        switch (error.code) {
        case 57: // Socket is not connected
            return YES;

        default:
            break;
        }
    }

    return NO;
}

+ (BOOL)isTemporalError:(NSError *)error
{
    return error != nil;
}

+ (BOOL)isNetworkReachabilityError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain]) {

        switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorCannotFindHost:
            return YES;

        default:
            break;
        }
    }

    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        return NO;
    }

    if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork]) {
        switch (error.code) {
        case kCFURLErrorNotConnectedToInternet:
        case kCFURLErrorDNSLookupFailed:
        case kCFURLErrorCannotFindHost:
            return YES;

        default:
            break;
        }
    }

    return NO;
}

+ (NSString *)hostFromReachabilityError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        NSURL *URL = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        return [URL host];
    }
    return nil;
}

#pragma mark Logging

+ (DDLogLevel)ddLogLevel
{
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel
{
    ddLogLevel = logLevel;
}

#pragma mark Life-cycle

- (instancetype)init
{
    return [self initWithKeyChainService:nil clientFactory:nil];
}

- (instancetype)initWithKeyChainService:(XMPPKeyChainService *)keyChainService
                          clientFactory:(XMPPClientFactory *)clientFactory
{
    self = [super init];
    if (self) {
        _keyChain = keyChainService;
        _clientFactory = clientFactory ?: [[XMPPClientFactory alloc] init];
        _operationQueue = dispatch_queue_create("XMPPAccountManager", DISPATCH_QUEUE_SERIAL);

        _clientsByAccount = [NSMapTable strongToStrongObjectsMapTable];
        _accounts = [[NSMutableArray alloc] init];
        _modules = [[NSMutableArray alloc] init];
        _networkReachabilitiesByClient = [NSMapTable weakToStrongObjectsMapTable];
        _dispatcher = [[XMPPDispatcher alloc] init];

        if (_keyChain) {
            for (XMPPJID *JID in [_keyChain identities]) {
                [self xmpp_createAccountWithJID:JID];
            }
        }
    }
    return self;
}

#pragma mark Exchange Pending Stanzas

- (void)exchangePendingStanzasWithTimeout:(NSTimeInterval)timeout
                               completion:(void (^)(NSError *error))completion
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_exchangePendingStanzasWithTimeout:timeout
                                          completion:completion];
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

- (XMPPAccount *)addAccountWithJID:(XMPPJID *)JID options:(NSDictionary *)options error:(NSError **)error
{
    __block XMPPAccount *account = nil;
    dispatch_sync(_operationQueue, ^{
        XMPPJID *bareJID = [JID bareJID];
        if ([self xmpp_accountWithJID:bareJID]) {
            if (error) {
                *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeAccountExists
                                         userInfo:@{}];
            }
        } else {
            account = [self xmpp_createAccountWithJID:bareJID];
            if (options) {
                [self xmpp_setOptions:options forAccount:account];
            }
        }
    });
    return account;
}

- (void)removeAccount:(XMPPAccount *)account
{
    dispatch_sync(_operationQueue, ^{
        [self xmpp_suspendAccounts:@[ account ]];
        [self xmpp_removeAccount:account];
    });
}

- (void)setOptions:(NSDictionary *)options forAccount:(XMPPAccount *)account
{
    dispatch_sync(_operationQueue, ^{
        [self xmpp_setOptions:options forAccount:account];
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

- (void)reconnectAccount:(XMPPAccount *)account
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_reconnectAccount:account];
    });
}

#pragma mark -

#pragma mark Accounts

- (NSArray *)xmpp_accounts
{
    return [_accounts copy];
}

- (XMPPAccount *)xmpp_accountWithJID:(XMPPJID *)JID
{
    for (XMPPAccount *account in _accounts) {
        if ([account.JID isEqual:JID]) {
            return account;
        }
    }
    return nil;
}

- (XMPPAccount *)xmpp_createAccountWithJID:(XMPPJID *)JID
{
    XMPPAccount *account = [[XMPPAccount alloc] initWithJID:JID accountManager:self keyChain:_keyChain];

    if (_keyChain) {
        [_keyChain addIdentitiyWithJID:JID];
        XMPPKeyChainItemAttributes *attributes = [_keyChain attributesForIdentityWithJID:JID];
        account.suspended = attributes.suspended;
        account.options = attributes.options;
    } else {
        account.suspended = YES;
    }

    [_accounts addObject:account];

    DDLogDebug(@"Did add account: %@", account);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidAddAccountNotification
                                                            object:self
                                                          userInfo:@{XMPPAccountManagerAccountKey : account}];
    });

    return account;
}

- (void)xmpp_removeAccount:(XMPPAccount *)account
{
    [self xmpp_removeClientForAccount:account];
    [_accounts removeObject:account];

    if (_keyChain) {
        [_keyChain removeIdentityWithJID:account.JID];
    }

    DDLogDebug(@"Did remove account: %@", account);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidRemoveAccountNotification
                                                            object:self
                                                          userInfo:@{XMPPAccountManagerAccountKey : account}];
    });
}

- (void)xmpp_setOptions:(NSDictionary *)options forAccount:(XMPPAccount *)account
{
    if (_keyChain) {
        XMPPKeyChainItemAttributes *attributes = [[XMPPKeyChainItemAttributes alloc] initWithOptions:options
                                                                                           suspended:account.suspended];
        [_keyChain setAttributes:attributes forIdentityWithJID:account.JID];
    }

    account.options = options;
    DDLogDebug(@"Did update options of account: %@ -- %@", account, options);

    if (account.connected) {
        DDLogDebug(@"Reconnecting account to apply the new options.");
        XMPPClient *client = [self xmpp_clientForAccount:account];
        if (client) {
            [client disconnect];
        }
    }
}

#pragma mark Clients

- (NSArray *)xmpp_clients
{
    return [[_clientsByAccount objectEnumerator] allObjects];
}

- (XMPPAccount *)xmpp_accountForClient:(XMPPClient *)client
{
    XMPPAccount *account = nil;
    for (XMPPAccount *a in _clientsByAccount) {
        if ([_clientsByAccount objectForKey:a] == client) {
            account = a;
            break;
        }
    }
    return account;
}

- (XMPPClient *)xmpp_clientForAccount:(XMPPAccount *)account
{
    XMPPClient *client = [_clientsByAccount objectForKey:account];
    return client;
}

- (XMPPClient *)xmpp_createClientForAccount:(XMPPAccount *)account
{
    XMPPClient *client = [_clientFactory createClientToHost:account.JID.host
                                                withOptions:account.options
                                                     stream:nil];

    client.delegateQueue = _operationQueue;
    client.delegate = self;
    client.SASLDelegate = self.SASLDelegate;
    client.SASLDelegateQueue = dispatch_get_main_queue();
    client.SASLContext = account;

    [_clientsByAccount setObject:client forKey:account];

    XMPPNetworkReachability *reachability = [[XMPPNetworkReachability alloc] initWithQueue:_operationQueue];
    reachability.delegate = self;
    [_networkReachabilitiesByClient setObject:reachability forKey:client];

    DDLogDebug(@"Did create client %@ for account %@", client, account);

    return client;
}

- (void)xmpp_removeClientForAccount:(XMPPAccount *)account
{
    XMPPClient *client = [_clientsByAccount objectForKey:account];
    client.delegate = nil;
    client.delegateQueue = nil;
    account.clientState = client.state;
    [_clientsByAccount removeObjectForKey:account];
    [_dispatcher removeConnection:client];

    DDLogDebug(@"Did remove client %@ for account %@", client, account);
}

#pragma mark Exchange Pending Stanzas

- (void)xmpp_exchangePendingStanzasWithTimeout:(NSTimeInterval)timeout
                                    completion:(void (^)(NSError *error))completion
{
    dispatch_group_t g = dispatch_group_create();

    __block NSMutableArray *errors = [[NSMutableArray alloc] init];

    for (XMPPAccount *account in [self xmpp_accounts]) {
        if (account.suspended == NO) {

            XMPPClient *client = [self xmpp_clientForAccount:account];
            if (client == nil) {
                client = [self xmpp_createClientForAccount:account];
                client.connectionDelegate = _dispatcher;
                [_dispatcher setConnection:client forJID:account.JID];
            }
            if (client.state != XMPPClientStateConnected) {
                [client updateOptions:account.options];
                [client connect];
            }

            dispatch_group_enter(g);

            [self xmpp_sendPingTo:[account.JID bareJID]
                             from:account.JID
                          timeout:timeout
                completionHandler:^(BOOL success, NSError *error) {
                    dispatch_group_leave(g);
                }];
        }
    }

    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        if (completion) {
            NSError *error = nil;
            if (errors) {
                error = [NSError errorWithDomain:XMPPErrorDomain
                                            code:XMPPErrorCodeUnknown
                                        userInfo:@{XMPPErrorUnderlyingErrorsKey : errors}];
            }
            completion(error);
        }
    });
}

#pragma mark Suspend & Resume

- (void)xmpp_suspendAccounts:(NSArray *)accounts
{
    for (XMPPAccount *account in accounts) {
        XMPPClient *client = [self xmpp_clientForAccount:account];
        if (client) {
            if (account.suspended == NO) {
                account.suspended = YES;

                if (_keyChain) {
                    XMPPKeyChainItemAttributes *attributes = [[XMPPKeyChainItemAttributes alloc] initWithOptions:account.options suspended:account.suspended];
                    [_keyChain setAttributes:attributes forIdentityWithJID:account.JID];
                }

                account.numberOfConnectionAttempts = 0;
                account.nextConnectionAttempt = nil;

                client.connectionDelegate = nil;
                [_dispatcher removeConnectionForJID:account.JID];

                if (client.state == XMPPClientStateConnected) {
                    [client disconnect];
                }

                DDLogInfo(@"Did suspend account: %@", account);

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidSuspendAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPAccountManagerAccountKey : account}];
                });
            }
        }
    }
}

- (void)xmpp_resumeAccounts:(NSArray *)accounts
{
    for (XMPPAccount *account in accounts) {
        XMPPClient *client = [self xmpp_clientForAccount:account];

        if (client == nil) {
            client = [self xmpp_createClientForAccount:account];
        }

        if (client) {
            if (account.suspended) {
                account.suspended = NO;

                if (_keyChain) {
                    XMPPKeyChainItemAttributes *attributes = [[XMPPKeyChainItemAttributes alloc] initWithOptions:account.options suspended:account.suspended];
                    [_keyChain setAttributes:attributes forIdentityWithJID:account.JID];
                }

                client.connectionDelegate = _dispatcher;
                [_dispatcher setConnection:client forJID:account.JID];

                if (client.state == XMPPClientStateDisconnected) {
                    [client updateOptions:account.options];
                    [client connect];
                }

                DDLogInfo(@"Did resume account: %@", account);

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidResumeAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPAccountManagerAccountKey : account}];
                });
            }
        }
    }
}

#pragma mark Reconnect

- (void)xmpp_reconnectAccount:(XMPPAccount *)account
{
    if (account.suspended == NO) {
        XMPPClient *client = [self xmpp_clientForAccount:account];

        if (client == nil) {
            client = [self xmpp_createClientForAccount:account];
        }

        client.connectionDelegate = _dispatcher;
        [_dispatcher setConnection:client forJID:account.JID];

        if (client.state == XMPPClientStateDisconnected) {
            [client updateOptions:account.options];
            [client connect];
        }

        DDLogInfo(@"Will reconnect account: %@", account);
    }
}

- (void)xmpp_reconnectClientForAccount:(XMPPAccount *)account error:(NSError *)error
{
    if (account.suspended == NO) {

        NSUInteger maxConnectionAttempts = 10;

        if (account.numberOfConnectionAttempts >= maxConnectionAttempts) {
            DDLogInfo(@"To many reconnection attempts for account '%@'. Giving up.", account);
        } else {
            account.numberOfConnectionAttempts += 1;
            DDLogInfo(@"Try to reconnect account '%@' (%lu)", account, (unsigned long)account.numberOfConnectionAttempts);

            XMPPClient *client = [self xmpp_clientForAccount:account];
            if (client == nil) {
                client = [self xmpp_createClientForAccount:account];
            }

            XMPPNetworkReachability *reachability = [_networkReachabilitiesByClient objectForKey:client];

            if (error == nil || [[self class] shouldReconnectImmediately:error]) {

                DDLogInfo(@"Client has been disconnected without an error. Just reconnecting immediately.");

                [reachability removeAllHostnames];
                account.needsReachabilityChange = NO;

                DDLogInfo(@"Reconnect client %@ for account %@.", client, account);

                [client updateOptions:account.options];
                [client connect];

            } else if ([[self class] isNetworkReachabilityError:error]) {

                DDLogInfo(@"Client has been disconnected due to a reachability error.");

                NSString *hostname = [[self class] hostFromReachabilityError:error];
                if (hostname == nil) {
                    hostname = account.JID.host;
                }
                [reachability addHostname:hostname];

                DDLogInfo(@"Start monitoring network reachability for host: %@", hostname);

            } else if ([[self class] isTemporalError:error]) {

                DDLogInfo(@"Client has been disconnected due to a temporal error.");

                [reachability removeAllHostnames];
                account.needsReachabilityChange = NO;

                NSTimeInterval defaultAttemptTimeInterval = 1.0;
                NSTimeInterval maxAttemptTimeInterval = 60.0;
                NSTimeInterval timeIntervalUntilNextAttempt = fmin(pow(2, account.numberOfConnectionAttempts) * defaultAttemptTimeInterval, maxAttemptTimeInterval);

                DDLogInfo(@"Will try to reconnect client %@ for account %@ in %f seconds.", client, account, timeIntervalUntilNextAttempt);

                account.nextConnectionAttempt = [NSDate dateWithTimeIntervalSinceNow:timeIntervalUntilNextAttempt];

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeIntervalUntilNextAttempt * NSEC_PER_SEC)), _operationQueue, ^{
                    account.nextConnectionAttempt = nil;
                    if (account.suspended) {
                        DDLogInfo(@"Will not try to reconnect account %@, because the account has been suspended.", account);
                    } else {

                        XMPPClient *client = [self xmpp_clientForAccount:account];
                        if (client == nil) {
                            client = [self xmpp_createClientForAccount:account];
                        }

                        DDLogInfo(@"Reconnect client %@ for account %@.", client, account);
                        [client updateOptions:account.options];
                        [client connect];
                    }
                });

            } else {
                DDLogInfo(@"Client has been disconnected due to a permanent error. Suspending Account.");
            }
        }
    } else {
        [self xmpp_removeClientForAccount:account];
    }
}

#pragma mark Ping

- (void)xmpp_sendPingTo:(XMPPJID *)to
                   from:(XMPPJID *)from
                timeout:(NSTimeInterval)timeout
      completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

    PXElement *iq = doc.root;
    [iq setValue:[to stringValue] forAttribute:@"to"];
    [iq setValue:[from stringValue] forAttribute:@"from"];
    [iq setValue:@"get" forAttribute:@"type"];

    NSString *requestID = [[NSUUID UUID] UUIDString];
    [iq setValue:requestID forAttribute:@"id"];

    [iq addElementWithName:@"ping" namespace:@"urn:xmpp:ping" content:nil];

    [_dispatcher handleIQRequest:iq
                         timeout:timeout
                      completion:^(PXElement *response, NSError *error) {
                          if (completionHandler) {
                              if (error) {
                                  completionHandler(NO, error);
                              } else {
                                  NSString *type = [response valueForAttribute:@"type"];
                                  if ([type isEqualToString:@"result"]) {
                                      completionHandler(YES, nil);
                                  } else if ([type isEqualToString:@"error"]) {
                                      NSError *error = [NSError errorFromStanza:response];
                                      completionHandler(NO, error);
                                  }
                              }
                          }
                      }];
}

#pragma mark -
#pragma mark XMPPClientDelegate (called on operation queue)

- (void)clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream
{
    XMPPAccount *account = [self xmpp_accountForClient:client];

    DDLogInfo(@"Client %@ for account %@ did connect.", client, account);

    if (account) {
        account.clientState = client.state;
        account.numberOfConnectionAttempts = 0;
        account.nextConnectionAttempt = nil;
        account.needsReachabilityChange = NO;
        account.recentError = nil;

        XMPPNetworkReachability *reachability = [_networkReachabilitiesByClient objectForKey:client];
        [reachability removeAllHostnames];

        // Send initial presence

        if (!resumedStream) {
            PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
            [doc.root setValue:[account.JID stringValue] forAttribute:@"from"];

            [_dispatcher handlePresence:doc.root
                             completion:^(NSError *error) {
                                 if (error) {
                                     NSLog(@"Failed to send initial presence: %@", [error localizedDescription]);
                                 }
                             }];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidConnectAccountNotification
                                                                object:self
                                                              userInfo:@{ XMPPAccountManagerAccountKey : account,
                                                                          XMPPAccountManagerResumedKey : @(resumedStream) }];

        });
    }
}

- (void)clientDidDisconnect:(XMPPClient *)client
{
    XMPPAccount *account = [self xmpp_accountForClient:client];

    DDLogInfo(@"Client %@ for account %@ did disconnect.", client, account);

    if (account) {

        account.clientState = client.state;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidDisconnectAccountNotification
                                                                object:self
                                                              userInfo:@{XMPPAccountManagerAccountKey : account}];

        });

        [self xmpp_reconnectClientForAccount:account error:nil];
    }
}

- (void)client:(XMPPClient *)client didFailToNegotiateFeature:(XMPPStreamFeature *)feature withError:(NSError *)error
{
    __unused XMPPAccount *account = [self xmpp_accountForClient:client];

    DDLogWarn(@"Client %@ for account %@ did fail to negotiate feature %@ with error: %@.", client, account, feature, [error localizedDescription]);
}

- (void)client:(XMPPClient *)client didFailWithError:(NSError *)error
{
    XMPPAccount *account = [self xmpp_accountForClient:client];
    account.recentError = error;

    DDLogError(@"Client %@ for account %@ did fail with error (%@, %ld): %@", client, account, error.domain, (long)error.code, [error localizedDescription]);

    if (account) {

        account.clientState = client.state;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerConnectionDidFailNotification
                                                                object:self
                                                              userInfo:@{XMPPAccountManagerAccountKey : account}];

        });

        [self xmpp_reconnectClientForAccount:account error:error];
    }
}

- (void)client:(XMPPClient *)client didChangeState:(XMPPClientState)state
{
    XMPPAccount *account = [self xmpp_accountForClient:client];
    account.clientState = client.state;
}

#pragma mark XMPPNetworkReachabilityDelegate (called on operation queue)

- (void)networkReachabilityDidChange:(XMPPNetworkReachability *)networkReachability
{
    XMPPClient *client = nil;
    for (XMPPClient *c in [_networkReachabilitiesByClient keyEnumerator]) {
        if ([_networkReachabilitiesByClient objectForKey:c] == networkReachability) {
            client = c;
            break;
        }
    }

    XMPPAccount *account = [self xmpp_accountForClient:client];
    if (account.suspended == NO &&
        account.connected == NO) {

        XMPPClient *client = [self xmpp_clientForAccount:account];
        if (client == nil) {
            client = [self xmpp_createClientForAccount:account];
        }

        if (client.state == XMPPClientStateDisconnected) {
            for (NSString *hostname in networkReachability.hostnames) {
                XMPPNetworkReachabilityStatus status = [networkReachability reachabilityStatusForHost:hostname];
                if (status == XMPPNetworkReachabilityStatusReachableViaWiFi ||
                    status == XMPPNetworkReachabilityStatusReachableViaWWAN) {
                    DDLogInfo(@"Reconnect client %@ for account %@.", client, account);
                    [client updateOptions:account.options];
                    [client connect];
                    break;
                }
            }
        }
    }
}

@end

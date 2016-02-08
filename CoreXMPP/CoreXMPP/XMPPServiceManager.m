//
//  XMPPServiceManager.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPError.h"
#import "XMPPJID.h"
#import "XMPPWebsocketStream.h"
#import "XMPPModule.h"
#import "XMPPPingModule.h"
#import "XMPPDispatcher.h"
#import "XMPPClient.h"
#import "XMPPAccount.h"
#import "XMPPAccount+Private.h"
#import "XMPPNetworkReachability.h"
#import "XMPPServiceManager.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPServiceManagerDidAddAccountNotification = @"XMPPServiceManagerDidAddAccountNotification";
NSString *const XMPPServiceManagerDidRemoveAccountNotification = @"XMPPServiceManagerDidRemoveAccountNotification";
NSString *const XMPPServiceManagerDidResumeAccountNotification = @"XMPPServiceManagerDidResumeAccountNotification";
NSString *const XMPPServiceManagerDidSuspendAccountNotification = @"XMPPServiceManagerDidSuspendAccountNotification";
NSString *const XMPPServiceManagerDidConnectAccountNotification = @"XMPPServiceManagerDidConnectAccountNotification";
NSString *const XMPPServiceManagerDidDisconnectAccountNotification = @"XMPPServiceManagerDidDisconnectAccountNotification";
NSString *const XMPPServiceManagerConnectionDidFailNotification = @"XMPPServiceManagerConnectionDidFailNotification";

NSString *const XMPPServiceManagerAccountKey = @"XMPPServiceManagerAccountKey";
NSString *const XMPPServiceManagerResumedKey = @"XMPPServiceManagerResumedKey";

NSString *const XMPPServiceManagerOptionClientFactoryCallbackKey = @"XMPPServiceManagerOptionClientFactoryCallbackKey";

@interface XMPPServiceManager () <XMPPClientDelegate, XMPPNetworkReachabilityDelegate> {
    dispatch_queue_t _operationQueue;
    NSMutableArray *_accounts;
    NSMapTable *_clientsByAccount;
    NSMapTable *_networkReachabilitiesByClient;
    XMPPDispatcher *_dispatcher;
    NSMutableArray *_modules;
}

@end

@implementation XMPPServiceManager

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

#pragma mark Registered Modules

+ (NSMutableDictionary *)xmpp_registeredModules
{
    static NSMutableDictionary *registeredModules;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registeredModules = [[NSMutableDictionary alloc] init];
    });
    return registeredModules;
}

+ (NSDictionary *)registeredModules
{
    return [self xmpp_registeredModules];
}

+ (void)registerModuleClass:(Class)moduleClass forModuleType:(NSString *)moduleType
{
    [[self xmpp_registeredModules] setObject:moduleClass forKey:moduleType];
}

#pragma mark Life-cycle

- (instancetype)initWithOptions:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _options = options;
        _operationQueue = dispatch_queue_create("XMPPServiceManager", DISPATCH_QUEUE_SERIAL);
        _clientsByAccount = [NSMapTable strongToStrongObjectsMapTable];
        _accounts = [[NSMutableArray alloc] init];
        _modules = [[NSMutableArray alloc] init];
        _networkReachabilitiesByClient = [NSMapTable weakToStrongObjectsMapTable];
        _dispatcher = [[XMPPDispatcher alloc] init];
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
                BOOL success = [self xmpp_setOptions:options forAccount:account error:error];
                if (!success) {
                    [self xmpp_removeAccount:account];
                    account = nil;
                }
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

- (BOOL)setOptions:(NSDictionary *)options forAccount:(XMPPAccount *)account error:(NSError **)error
{
    __block BOOL success = NO;
    dispatch_sync(_operationQueue, ^{
        success = [self xmpp_setOptions:options forAccount:account error:error];
    });
    return success;
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

#pragma mark Manage Modules

- (NSArray *)modules
{
    __block NSArray *modules = nil;
    dispatch_sync(_operationQueue, ^{
        modules = [self xmpp_modules];
    });
    return modules;
}

- (XMPPModule *)addModuleWithType:(NSString *)moduleType options:(NSDictionary *)options error:(NSError **)error
{
    __block XMPPModule *module = nil;
    dispatch_sync(_operationQueue, ^{
        module = [self xmpp_addModuleWithType:moduleType options:options error:error];
    });
    return module;
}

- (void)removeModule:(XMPPModule *)module
{
    dispatch_async(_operationQueue, ^{
        [self xmpp_removeModule:module];
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
    XMPPAccount *account = [[XMPPAccount alloc] initWithJID:JID serviceManager:self];
    account.suspended = YES;
    account.connected = NO;
    [_accounts addObject:account];

    DDLogDebug(@"Did add account: %@", account);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidAddAccountNotification
                                                            object:self
                                                          userInfo:@{XMPPServiceManagerAccountKey : account}];
    });

    return account;
}

- (void)xmpp_removeAccount:(XMPPAccount *)account
{
    [self xmpp_removeClientForAccount:account];
    [_accounts removeObject:account];

    DDLogDebug(@"Did remove account: %@", account);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidRemoveAccountNotification
                                                            object:self
                                                          userInfo:@{XMPPServiceManagerAccountKey : account}];
    });
}

- (BOOL)xmpp_setOptions:(NSDictionary *)options forAccount:(XMPPAccount *)account error:(NSError **)error
{
    if (account.suspended) {
        account.options = options;
        DDLogDebug(@"Did update options of account: %@ -- %@", account, options);
        return YES;
    } else {
        DDLogError(@"Can not update options of an account, that is not suspended: %@ -- %@", account, options);
        if (error) {
            NSString *errorMessasge = [NSString stringWithFormat:@"Can not update options of an account, that is not suspended: %@ -- %@", account, options];
            *error = [NSError errorWithDomain:XMPPErrorDomain
                                         code:XMPPErrorCodeInvalidState
                                     userInfo:@{NSLocalizedDescriptionKey : errorMessasge}];
        }
        return NO;
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
    XMPPClient *client = nil;

    XMPPServiceManagerClientFactoryCallback callback = self.options[XMPPServiceManagerOptionClientFactoryCallbackKey];
    if (callback) {
        client = callback(account, account.options);
    }

    if (client == nil) {
        NSString *hostname = account.JID.host;
        client = [[XMPPClient alloc] initWithHostname:hostname
                                              options:account.options];
    }

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
    account.connected = NO;
    [_clientsByAccount removeObjectForKey:account];
    [_dispatcher removeConnection:client];

    DDLogDebug(@"Did remove client %@ for account %@", client, account);
}

#pragma mark Modules

- (NSArray *)xmpp_modules
{
    return [_modules copy];
}

- (XMPPModule *)xmpp_addModuleWithType:(NSString *)moduleType options:(NSDictionary *)options error:(NSError **)error
{
    Class moduleClass = [[[self class] registeredModules] objectForKey:moduleType];
    if (moduleClass) {
        XMPPModule *module = [[moduleClass alloc] initWithServiceManager:self
                                                              dispatcher:_dispatcher
                                                                 options:options];
        BOOL loaded = [module loadModule:error];
        if (loaded) {
            [_modules addObject:module];
            return module;
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (void)xmpp_removeModule:(XMPPModule *)module
{
    [_dispatcher removeHandler:module];
    [_modules removeObject:module];
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
            }
            if (client.state != XMPPClientStateConnected) {
                [client connect];
            }

            dispatch_group_enter(g);
            [XMPPPingModule sendPingUsingIQHandler:_dispatcher
                                                to:[account.JID bareJID]
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
                account.numberOfConnectionAttempts = 0;
                account.nextConnectionAttempt = nil;

                client.stanzaHandler = nil;
                [_dispatcher removeConnectionForJID:account.JID];

                if (client.state == XMPPClientStateConnected) {
                    [client disconnect];
                }

                DDLogInfo(@"Did suspend account: %@", account);

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidSuspendAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPServiceManagerAccountKey : account}];
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

                client.stanzaHandler = _dispatcher;
                [_dispatcher setConnection:client forJID:account.JID];

                if (client.state == XMPPClientStateDisconnected) {
                    [client connect];
                }

                DDLogInfo(@"Did resume account: %@", account);

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidResumeAccountNotification
                                                                        object:self
                                                                      userInfo:@{XMPPServiceManagerAccountKey : account}];
                });
            }
        }
    }
}

#pragma mark Reconnect

- (void)xmpp_reconnectClientForAccount:(XMPPAccount *)account error:(NSError *)error
{
    if (account.suspended == NO) {

        NSUInteger maxConnectionAttempts = 10;

        if (account.numberOfConnectionAttempts >= maxConnectionAttempts) {
            DDLogInfo(@"Suspending account '%@' due to to many reconnection attempts.", account);
            [self xmpp_suspendAccounts:@[ account ]];
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
                NSTimeInterval timeIntervalUntilNextAttempt = pow(2, account.numberOfConnectionAttempts) * defaultAttemptTimeInterval;

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
                        [client connect];
                    }
                });

            } else {

                DDLogInfo(@"Client has been disconnected due to a permanent error. Suspending Account.");
                [self xmpp_suspendAccounts:@[ account ]];
            }
        }

    } else {
        [self xmpp_removeClientForAccount:account];
    }
}

#pragma mark -
#pragma mark XMPPClientDelegate (called on operation queue)

- (void)clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream
{
    XMPPAccount *account = [self xmpp_accountForClient:client];

    DDLogInfo(@"Client %@ for account %@ did connect.", client, account);

    if (account) {
        account.connected = YES;
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
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidConnectAccountNotification
                                                                object:self
                                                              userInfo:@{ XMPPServiceManagerAccountKey : account,
                                                                          XMPPServiceManagerResumedKey : @(resumedStream) }];

        });
    }
}

- (void)clientDidDisconnect:(XMPPClient *)client
{
    XMPPAccount *account = [self xmpp_accountForClient:client];

    DDLogInfo(@"Client %@ for account %@ did disconnect.", client, account);

    if (account) {

        account.connected = NO;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidDisconnectAccountNotification
                                                                object:self
                                                              userInfo:@{XMPPServiceManagerAccountKey : account}];

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

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerConnectionDidFailNotification
                                                                object:self
                                                              userInfo:@{XMPPServiceManagerAccountKey : account}];

        });

        if (account.connected) {
            account.connected = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:XMPPServiceManagerDidDisconnectAccountNotification
                                                                    object:self
                                                                  userInfo:@{XMPPServiceManagerAccountKey : account}];

            });
        }

        [self xmpp_reconnectClientForAccount:account error:error];
    }
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
                    [client connect];
                    break;
                }
            }
        }
    }
}

@end

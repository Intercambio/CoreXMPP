//
//  XMPPAccountManager.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
//

#import "XMPPAccountManager.h"
#import "XMPPAccountConnectivityImpl.h"
#import "XMPPClient.h"
#import "XMPPClientFactoryImpl.h"
#import "XMPPError.h"

NSString *const XMPPAccountManagerDidAddAccount = @"XMPPAccountManagerDidAddAccount";
NSString *const XMPPAccountManagerDidRemoveAccount = @"XMPPAccountManagerDidRemoveAccount";
NSString *const XMPPAccountManagerDidChangeAccount = @"XMPPAccountManagerDidChangeAccount";
NSString *const XMPPAccountConnectivityDidChangeNotification = @"XMPPAccountConnectivityDidChangeNotification";
NSString *const XMPPAccountManagerAccountJIDKey = @"XMPPAccountManagerAccountJIDKey";
NSString *const XMPPAccountManagerAccountInfoKey = @"XMPPAccountManagerAccountInfoKey";

@interface XMPPAccountManager () <XMPPAccountConnectivityImplDelegate> {
    id<XMPPClientFactory> _clientFactory;
    NSMutableDictionary *_clientsByAccount;
    NSMutableDictionary *_connectivityByAccount;
}

@end

@implementation XMPPAccountManager

#pragma mark Life-cycle

- (instancetype)initWithDispatcher:(XMPPDispatcherImpl *)dispatcher
{
    return [self initWithDispatcher:dispatcher
                      clientFactory:nil];
}

- (instancetype)initWithDispatcher:(XMPPDispatcherImpl *)dispatcher
                     clientFactory:(id<XMPPClientFactory>)clientFactory
{
    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _clientFactory = clientFactory ?: [[XMPPClientFactoryImpl alloc] init];
        _clientsByAccount = [[NSMutableDictionary alloc] init];
        _connectivityByAccount = [[NSMutableDictionary alloc] init];
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

        XMPPAccountConnectivityImpl *connectivity = [[XMPPAccountConnectivityImpl alloc] initWithAccount:account
                                                                                                  client:client];

        [_connectivityByAccount setObject:connectivity forKey:account];

        connectivity.delegate = self;

        client.delegate = connectivity;
        client.delegateQueue = dispatch_get_main_queue();

        client.connectionDelegate = _dispatcher;
        [_dispatcher setConnection:client forJID:account];

        client.SASLContext = account;
        client.SASLDelegate = self.SASLDelegate;
        client.SASLDelegateQueue = dispatch_get_main_queue();

        [client connect];

        NSDictionary *userInfo = @{XMPPAccountManagerAccountJIDKey : account};

        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidAddAccount
                                                            object:self
                                                          userInfo:userInfo];

        return YES;
    }
}

- (void)updateAccount:(XMPPJID *)account withOptions:(NSDictionary<NSString *, id> *)options
{
    XMPPClient *client = [_clientsByAccount objectForKey:account];
    [client updateOptions:options];
}

- (void)removeAccount:(XMPPJID *)account
{
    [_clientsByAccount removeObjectForKey:account];
    [_connectivityByAccount removeObjectForKey:account];

    NSDictionary *userInfo = @{XMPPAccountManagerAccountJIDKey : account};

    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidRemoveAccount
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)connectAccount:(XMPPJID *)account
{
    id<XMPPAccountConnectivity> connectivity = [_connectivityByAccount objectForKey:account];
    [connectivity connect];
}

#pragma mark Account Info

- (id<XMPPAccountInfo>)infoForAccount:(XMPPJID *)account
{
    return [_connectivityByAccount objectForKey:account];
}

#pragma mark Acknowledgements

- (void)exchangeAcknowledgements
{
    [_clientsByAccount enumerateKeysAndObjectsUsingBlock:^(XMPPJID *account, XMPPClient *client, BOOL *_Nonnull stop) {
        [client exchangeAcknowledgement];
    }];
}

#pragma mark XMPPAccountConnectivityImplDelegate

- (id<XMPPReconnectStrategy>)accountConnectivity:(XMPPAccountConnectivityImpl *)accountConnectivity
                      reconnectStrategyForClient:(XMPPClient *)client
                                       withError:(NSError *)error
                                numberOfAttempts:(NSUInteger)numberOfAttempts
{
    return [_clientFactory reconnectStrategyForClient:client
                                            withError:error
                                     numberOfAttempts:numberOfAttempts];
}

- (void)accountConnectivityDidChange:(XMPPAccountConnectivityImpl *)accountConnectivity
{
    NSDictionary *userInfo = @{XMPPAccountManagerAccountJIDKey : accountConnectivity.account,
                               XMPPAccountManagerAccountInfoKey : accountConnectivity};

    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPAccountManagerDidChangeAccount
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark Deprecated

- (void)updateOptions:(NSDictionary<NSString *, id> *)options forAccount:(XMPPJID *)account
{
    [self updateAccount:account withOptions:options];
}

- (id<XMPPAccountConnectivity>)connectivityForAccount:(XMPPJID *)account
{
    return [_connectivityByAccount objectForKey:account];
}

@end

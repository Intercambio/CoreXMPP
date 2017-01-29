//
//  XMPPAccountManager.h
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

@import Foundation;
@import XMPPFoundation;

#import "XMPPAccountConnectivity.h"
#import "XMPPClientFactory.h"
#import "XMPPDispatcherImpl.h"

#import <SASLKit/SASLKit.h>

extern NSString *_Nonnull const XMPPAccountManagerDidAddAccount NS_SWIFT_NAME(AccountManagerDidAddAccount);
extern NSString *_Nonnull const XMPPAccountManagerDidRemoveAccount NS_SWIFT_NAME(AccountManagerDidRemoveAccount);
extern NSString *_Nonnull const XMPPAccountManagerDidChangeAccount NS_SWIFT_NAME(AccountManagerDidChangeAccount);

extern NSString *_Nonnull const XMPPAccountManagerAccountJIDKey NS_SWIFT_NAME(AccountManagerAccountJIDKey);
extern NSString *_Nonnull const XMPPAccountManagerAccountInfoKey NS_SWIFT_NAME(AccountManagerAccountInfoKey);

NS_SWIFT_NAME(AccountManager)
@interface XMPPAccountManager : NSObject

#pragma mark Life-cycle
- (nonnull instancetype)initWithDispatcher:(nonnull XMPPDispatcherImpl *)dispatcher;
- (nonnull instancetype)initWithDispatcher:(nonnull XMPPDispatcherImpl *)dispatcher
                             clientFactory:(nullable id<XMPPClientFactory>)clientFactory;

#pragma mark Dispatcher
@property (nonatomic, readonly) XMPPDispatcherImpl *_Nonnull dispatcher;

#pragma mark SASL Delegate
@property (nonatomic, weak) id<SASLMechanismDelegate> _Nullable SASLDelegate;

#pragma mark Managing Accounts
@property (nonatomic, readonly) NSArray<XMPPJID *> *_Nonnull accounts;
- (BOOL)addAccount:(nonnull XMPPJID *)account
       withOptions:(nonnull NSDictionary<NSString *, id> *)options
             error:(NSError *__autoreleasing __nullable *__nullable)error NS_SWIFT_NAME(addAccount(_:options:));
- (void)updateAccount:(nonnull XMPPJID *)account withOptions:(nonnull NSDictionary<NSString *, id> *)options;
- (void)removeAccount:(nonnull XMPPJID *)account;

- (void)connectAccount:(nonnull XMPPJID *)account NS_SWIFT_NAME(connect(_:));

#pragma mark Account Info
- (nullable id<XMPPAccountInfo>)infoForAccount:(nonnull XMPPJID *)account NS_SWIFT_NAME(info(for:));

#pragma mark Acknowledgements
- (void)exchangeAcknowledgements;

#pragma mark Deprecated
- (void)updateOptions:(nonnull NSDictionary<NSString *, id> *)options forAccount:(nonnull XMPPJID *)account __attribute__((deprecated));
- (nullable id<XMPPAccountConnectivity>)connectivityForAccount:(XMPPJID *_Nonnull)account NS_SWIFT_NAME(connectivity(for:)) __attribute__((deprecated));

@end

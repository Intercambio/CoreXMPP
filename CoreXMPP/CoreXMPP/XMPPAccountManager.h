//
//  XMPPAccountManager.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPAccountConnectivity.h"
#import "XMPPClientFactory.h"
#import "XMPPDispatcher.h"
#import "XMPPJID.h"
#import <Foundation/Foundation.h>
#import <SASLKit/SASLKit.h>

extern NSString *_Nonnull const XMPPAccountManagerDidAddAccount NS_SWIFT_NAME(AccountManagerDidAddAccount);
extern NSString *_Nonnull const XMPPAccountManagerDidRemoveAccount NS_SWIFT_NAME(AccountManagerDidRemoveAccount);
extern NSString *_Nonnull const XMPPAccountManagerDidChangeAccount NS_SWIFT_NAME(AccountManagerDidChangeAccount);

extern NSString *_Nonnull const XMPPAccountManagerAccountJIDKey NS_SWIFT_NAME(AccountManagerAccountJIDKey);
extern NSString *_Nonnull const XMPPAccountManagerAccountInfoKey NS_SWIFT_NAME(AccountManagerAccountInfoKey);

NS_SWIFT_NAME(AccountManager)
@interface XMPPAccountManager : NSObject

#pragma mark Life-cycle
- (nonnull instancetype)initWithDispatcher:(nonnull XMPPDispatcher *)dispatcher;
- (nonnull instancetype)initWithDispatcher:(nonnull XMPPDispatcher *)dispatcher
                             clientFactory:(nullable id<XMPPClientFactory>)clientFactory;

#pragma mark Dispatcher
@property (nonatomic, readonly) XMPPDispatcher *_Nonnull dispatcher;

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

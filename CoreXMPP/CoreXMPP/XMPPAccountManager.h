//
//  XMPPAccountManager.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SASLMechanismDelegate;
@class SASLMechanism;
@class XMPPAccount;
@class XMPPClient;
@class XMPPModule;
@class XMPPAccountManager;
@class XMPPDispatcher;

extern NSString *const XMPPAccountManagerDidAddAccountNotification;
extern NSString *const XMPPAccountManagerDidRemoveAccountNotification;
extern NSString *const XMPPAccountManagerDidResumeAccountNotification;
extern NSString *const XMPPAccountManagerDidSuspendAccountNotification;
extern NSString *const XMPPAccountManagerDidConnectAccountNotification;
extern NSString *const XMPPAccountManagerDidDisconnectAccountNotification;
extern NSString *const XMPPAccountManagerConnectionDidFailNotification;

extern NSString *const XMPPAccountManagerAccountKey;
extern NSString *const XMPPAccountManagerResumedKey;

extern NSString *const XMPPAccountManagerOptionClientFactoryCallbackKey;
extern NSString *const XMPPAccountManagerOptionsKeyChainServiceKey;

typedef XMPPClient * (^XMPPAccountManagerClientFactoryCallback)(XMPPAccount *account, NSDictionary *options);

@protocol XMPPAccountManagerDelegate <NSObject>
@optional
- (void)accountManager:(XMPPAccountManager *)accountManager didFailWithError:(NSError *)error;
@end

@interface XMPPAccountManager : NSObject

#pragma mark Life-cycle
- (instancetype)initWithOptions:(NSDictionary *)options;

#pragma mark Options
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPAccountManagerDelegate> delegate;
@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;

#pragma mark Dispatcher
@property (nonatomic, readonly) XMPPDispatcher *dispatcher;

#pragma mark Managing Accounts
@property (nonatomic, readonly) NSArray *accounts;
- (XMPPAccount *)addAccountWithJID:(XMPPJID *)JID options:(NSDictionary *)options error:(NSError **)error;
- (void)setOptions:(NSDictionary *)options forAccount:(XMPPAccount *)account;
- (void)removeAccount:(XMPPAccount *)account;

- (void)suspendAccount:(XMPPAccount *)account;
- (void)resumeAccount:(XMPPAccount *)resume;
- (void)suspendAllAccounts;
- (void)resumeAllAccounts;

- (void)reconnectAccount:(XMPPAccount *)account;

#pragma mark Exchange Pending Stanzas
- (void)exchangePendingStanzasWithTimeout:(NSTimeInterval)timeout
                               completion:(void (^)(NSError *error))completion;

@end

//
//  XMPPServiceManager.h
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
@class XMPPServiceManager;

extern NSString *const XMPPServiceManagerDidAddAccountNotification;
extern NSString *const XMPPServiceManagerDidRemoveAccountNotification;
extern NSString *const XMPPServiceManagerDidResumeAccountNotification;
extern NSString *const XMPPServiceManagerDidSuspendAccountNotification;
extern NSString *const XMPPServiceManagerDidConnectAccountNotification;
extern NSString *const XMPPServiceManagerDidDisconnectAccountNotification;
extern NSString *const XMPPServiceManagerConnectionDidFailNotification;

extern NSString *const XMPPServiceManagerAccountKey;
extern NSString *const XMPPServiceManagerResumedKey;

extern NSString *const XMPPServiceManagerOptionClientFactoryCallbackKey;
extern NSString *const XMPPServiceManagerOptionsKeyChainServiceKey;

typedef XMPPClient * (^XMPPServiceManagerClientFactoryCallback)(XMPPAccount *account, NSDictionary *options);

@protocol XMPPServiceManagerDelegate <NSObject>
@optional
- (void)serviceManager:(XMPPServiceManager *)serviceManager didFailWithError:(NSError *)error;
@end

@interface XMPPServiceManager : NSObject

#pragma mark Registered Modules
+ (NSDictionary *)registeredModules;
+ (void)registerModuleClass:(Class)moduleClass forModuleType:(NSString *)moduleType;

#pragma mark Life-cycle
- (instancetype)initWithOptions:(NSDictionary *)options;

#pragma mark Options
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPServiceManagerDelegate> delegate;
@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;

#pragma mark Manage Modules
@property (nonatomic, readonly) NSArray *modules;
- (XMPPModule *)addModuleWithType:(NSString *)moduleType options:(NSDictionary *)options error:(NSError **)error;
- (void)removeModule:(XMPPModule *)module;

#pragma mark Managing Accounts
@property (nonatomic, readonly) NSArray *accounts;
- (XMPPAccount *)addAccountWithJID:(XMPPJID *)JID options:(NSDictionary *)options error:(NSError **)error;
- (void)setOptions:(NSDictionary *)options forAccount:(XMPPAccount *)account;
- (void)removeAccount:(XMPPAccount *)account;

- (void)suspendAccount:(XMPPAccount *)account;
- (void)resumeAccount:(XMPPAccount *)resume;
- (void)suspendAllAccounts;
- (void)resumeAllAccounts;

#pragma mark Exchange Pending Stanzas
- (void)exchangePendingStanzasWithTimeout:(NSTimeInterval)timeout
                               completion:(void (^)(NSError *error))completion;

@end

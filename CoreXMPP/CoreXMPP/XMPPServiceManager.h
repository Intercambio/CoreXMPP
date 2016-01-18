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
@class XMPPServiceManager;

extern NSString *const XMPPServiceManagerDidResumeAccountNotification;
extern NSString *const XMPPServiceManagerDidSuspendAccountNotification;
extern NSString *const XMPPServiceManagerDidConnectAccountNotification;
extern NSString *const XMPPServiceManagerDidDisconnectAccountNotification;

extern NSString *const XMPPServiceManagerAccountKey;

extern NSString *const XMPPServiceManagerOptionClientFactoryCallbackKey;

typedef XMPPClient * (^XMPPServiceManagerClientFactoryCallback)(XMPPAccount *account, NSDictionary *options);

@protocol XMPPServiceManagerDelegate <NSObject>
@optional
- (void)serviceManager:(XMPPServiceManager *)serviceManager didFailWithError:(NSError *)error;
@end

@interface XMPPServiceManager : NSObject

#pragma mark Life-cycle
- (instancetype)initWithOptions:(NSDictionary *)options;

#pragma mark Options
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPServiceManagerDelegate> delegate;
@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;

#pragma mark Managing Service Manager
@property (nonatomic, readonly, getter=isSuspended) BOOL suspended;
- (void)suspend;
- (void)resume;

#pragma mark Managing Accounts
@property (nonatomic, readonly) NSArray *accounts;
- (XMPPAccount *)accountWithJID:(NSString *)jid;
- (void)removeAccount:(XMPPAccount *)account;

- (void)suspendAccount:(XMPPAccount *)account;
- (void)resumeAccount:(XMPPAccount *)resume;
- (void)suspendAllAccounts;
- (void)resumeAllAccounts;

@end

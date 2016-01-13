//
//  XMPPServiceManager.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const XMPPServiceManagerDidResumeAccountNotification;
extern NSString *const XMPPServiceManagerDidSuspendAccountNotification;
extern NSString *const XMPPServiceManagerDidConnectAccountNotification;
extern NSString *const XMPPServiceManagerDidDisconnectAccountNotification;

extern NSString *const XMPPServiceManagerAccountKey;

@class SASLMechanism;
@class XMPPAccount;
@class XMPPServiceManager;

@protocol XMPPServiceManagerDelegate <NSObject>
@optional
- (void)serviceManager:(XMPPServiceManager *)serviceManager account:(XMPPAccount *)account needsCredentialsForSASLMechanism:(SASLMechanism *)mechanism;
- (void)serviceManager:(XMPPServiceManager *)serviceManager didFailWithError:(NSError *)error;
@end

@interface XMPPServiceManager : NSObject

#pragma mark Life-cycle
- (instancetype)initWithOptions:(NSDictionary *)options;

#pragma mark Options
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPServiceManagerDelegate> delegate;

#pragma mark Managing Accounts
@property (nonatomic, readonly) NSArray *accounts;
- (XMPPAccount *)accountWithJID:(NSString *)jid;
- (void)removeAccount:(XMPPAccount *)account;

- (void)suspendAccount:(XMPPAccount *)account;
- (void)resumeAccount:(XMPPAccount *)resume;
- (void)suspendAllAccounts;
- (void)resumeAllAccounts;

@end

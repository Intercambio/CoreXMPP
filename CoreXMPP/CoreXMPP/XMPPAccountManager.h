//
//  XMPPAccountManager.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientFactory.h"
#import "XMPPDispatcher.h"
#import "XMPPJID.h"
#import <Foundation/Foundation.h>
#import <SASLKit/SASLKit.h>

typedef NS_ENUM(NSUInteger, XMPPAccountConnectivityState) {
    XMPPAccountConnectivityStateDisconnected,
    XMPPAccountConnectivityStateConnecting,
    XMPPAccountConnectivityStateConnected,
    XMPPAccountConnectivityStateDisconnecting
};

extern NSString *const XMPPAccountConnectivityDidChangeNotification;

@protocol XMPPAccountConnectivity <NSObject>
@property (nonatomic, readonly) XMPPJID *account;
@property (nonatomic, readwrite) BOOL shouldReconnect;
@property (nonatomic, readonly) XMPPAccountConnectivityState state;
@property (nonatomic, readonly) NSError *recentError;
@property (nonatomic, readonly) NSDate *nextConnectionAttempt;
- (void)connect;
@end

@interface XMPPAccountManager : NSObject

#pragma mark Life-cycle
- (instancetype)initWithDispatcher:(XMPPDispatcher *)dispatcher;
- (instancetype)initWithDispatcher:(XMPPDispatcher *)dispatcher
                     clientFactory:(XMPPClientFactory *)clientFactory;

#pragma mark Dispatcher
@property (nonatomic, readonly) XMPPDispatcher *dispatcher;

#pragma mark SASL Delegate
@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;

#pragma mark Managing Accounts
@property (nonatomic, readonly) NSArray *accounts;
- (BOOL)addAccount:(XMPPJID *)account withOptions:(NSDictionary *)options error:(NSError **)error;
- (void)updateOptions:(NSDictionary *)options forAccount:(XMPPJID *)account;
- (void)removeAccount:(XMPPJID *)account;

#pragma mark Connectivity
- (id<XMPPAccountConnectivity>)connectivityForAccount:(XMPPJID *)account;

#pragma mark Acknowledgements
- (void)exchangeAcknowledgements;

@end

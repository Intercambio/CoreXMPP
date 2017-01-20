//
//  XMPPAccountConnectivityImpl.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

@import Foundation;
@import XMPPFoundation;

#import "XMPPAccountManager.h"
#import "XMPPClient.h"
#import "XMPPReconnectStrategy.h"

@class XMPPAccountConnectivityImpl;

@protocol XMPPAccountConnectivityImplDelegate <NSObject>
- (id<XMPPReconnectStrategy>)accountConnectivity:(XMPPAccountConnectivityImpl *)accountConnectivity
                      reconnectStrategyForClient:(XMPPClient *)client
                                       withError:(NSError *)error
                                numberOfAttempts:(NSUInteger)numberOfAttempts;
@optional
- (void)accountConnectivityDidChange:(XMPPAccountConnectivityImpl *)accountConnectivity;
@end

@interface XMPPAccountConnectivityImpl : NSObject <XMPPAccountConnectivity, XMPPClientDelegate>

#pragma mark Life-cycle
- (instancetype)initWithAccount:(XMPPJID *)account
                         client:(XMPPClient *)client;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPAccountConnectivityImplDelegate> delegate;

#pragma mark Client
@property (nonatomic, readonly, weak) XMPPClient *client;

@end

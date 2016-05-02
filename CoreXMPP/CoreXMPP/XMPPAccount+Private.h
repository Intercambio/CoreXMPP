//
//  XMPPAccount+Private.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPAccount.h"
#import "XMPPAccountManager.h"
#import "XMPPKeyChainService.h"

@interface XMPPAccount (Private)

- (instancetype)initWithJID:(XMPPJID *)JID
             accountManager:(XMPPAccountManager *)accountManager
                   keyChain:(XMPPKeyChainService *)keyChain;

@property (nonatomic, readonly) XMPPKeyChainService *keyChain;

@property (nonatomic, readwrite) NSDictionary *options;
@property (nonatomic, readwrite) BOOL suspended;
@property (nonatomic, readwrite) XMPPClientState clientState;

@property (nonatomic, readwrite) NSUInteger numberOfConnectionAttempts;
@property (nonatomic, readwrite) NSDate *nextConnectionAttempt;
@property (nonatomic, readwrite) BOOL needsReachabilityChange;
@property (nonatomic, readwrite) NSError *recentError;

@end

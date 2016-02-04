//
//  XMPPAccount+Private.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPServiceManager.h"
#import "XMPPAccount.h"

@interface XMPPAccount (Private)

- (instancetype)initWithJID:(XMPPJID *)JID
             serviceManager:(XMPPServiceManager *)serviceManager;

@property (nonatomic, readwrite) NSDictionary *options;
@property (nonatomic, readwrite) BOOL suspended;
@property (nonatomic, readwrite) BOOL connected;

@property (nonatomic, readwrite) NSUInteger numberOfConnectionAttempts;
@property (nonatomic, readwrite) NSDate *nextConnectionAttempt;
@property (nonatomic, readwrite) BOOL needsReachabilityChange;
@property (nonatomic, readwrite) NSError *recentError;

@end

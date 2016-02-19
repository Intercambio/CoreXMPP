//
//  XMPPAccount.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPServiceManager;
@class XMPPJID;

@interface XMPPAccount : NSObject

@property (nonatomic, readonly) XMPPJID *JID;
@property (nonatomic, readonly, weak) XMPPServiceManager *serviceManger;

#pragma mark Account Attributes
@property (nonatomic, readonly) BOOL suspended;
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Account Connection State
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) NSUInteger numberOfConnectionAttempts;
@property (nonatomic, readonly) NSDate *nextConnectionAttempt;
@property (nonatomic, readonly) BOOL needsReachabilityChange;
@property (nonatomic, readonly) NSError *recentError;

@end

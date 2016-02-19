//
//  XMPPKeyChainService.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 19.02.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPJID;
@class XMPPKeyChainItemAttributes;

@interface XMPPKeyChainService : NSObject

#pragma mark Life-cycle
- (instancetype)initWithServiceName:(NSString *)serviceName;

#pragma mark Service Name
@property (nonatomic, readonly) NSString *serviceName;

#pragma mark Managing Identities
- (NSArray *)identities;
- (void)addIdentitiyWithJID:(XMPPJID *)JID;
- (void)removeIdentityWithJID:(XMPPJID *)JID;

#pragma mark Attributes
- (XMPPKeyChainItemAttributes *)attributesForIdentityWithJID:(XMPPJID *)JID;
- (void)setAttributes:(XMPPKeyChainItemAttributes *)attributes forIdentityWithJID:(XMPPJID *)JID;

#pragma mark Password
- (NSString *)passwordForIdentityWithJID:(XMPPJID *)JID;
- (void)setPassword:(NSString *)password forIdentityWithJID:(XMPPJID *)JID;

@end

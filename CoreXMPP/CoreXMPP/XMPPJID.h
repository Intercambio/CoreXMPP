//
//  XMPPJID.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#define JID(x) [XMPPJID JIDFromString:x]

@interface XMPPJID : NSObject

#pragma mark Life-cycle
+ (instancetype)JIDFromString:(NSString *)string;
- (instancetype)initWithUser:(NSString *)user host:(NSString *)host resource:(NSString *)resource NS_DESIGNATED_INITIALIZER;

#pragma mark JID Properties
@property (readonly, copy) NSString *user;
@property (readonly, copy) NSString *host;
@property (readonly, copy) NSString *resource;

#pragma mark String Value
@property (readonly, copy) NSString *stringValue;

#pragma mark Bare or Full JID
- (XMPPJID *)bareJID;
- (XMPPJID *)JIDWithResource:(NSString *)resource;

@end

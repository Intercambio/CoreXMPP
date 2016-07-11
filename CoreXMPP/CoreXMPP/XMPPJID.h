//
//  XMPPJID.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#define JID(x) [[XMPPJID alloc] initWithString:x]

NS_SWIFT_NAME(JID)
@interface XMPPJID : NSObject <NSCopying>

#pragma mark Life-cycle
- (nonnull instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithString:(nullable NSString *)string NS_SWIFT_NAME(init(_:));

- (nullable instancetype)initWithUser:(nullable NSString *)user
                                 host:(nonnull NSString *)host
                             resource:(nullable NSString *)resource NS_DESIGNATED_INITIALIZER;

#pragma mark JID Properties
@property (readonly) NSString *_Nullable user;
@property (readonly) NSString *_Nonnull host;
@property (readonly) NSString *_Nullable resource;

#pragma mark String Value
@property (readonly) NSString *_Nonnull stringValue;

#pragma mark Bare or Full JID
- (nonnull instancetype)bareJID;
- (nonnull instancetype)fullJIDWithResource:(nonnull NSString *)resource NS_SWIFT_NAME(fullJID(resource:));

+ (nullable instancetype)JIDFromString:(nullable NSString *)string __attribute__((deprecated));
- (nonnull instancetype)JIDWithResource:(nonnull NSString *)resource __attribute__((deprecated));

@end

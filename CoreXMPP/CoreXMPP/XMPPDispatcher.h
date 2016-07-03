//
//  XMPPDispatcher.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPConnection.h"
#import "XMPPDocumentHandler.h"

@class PXQName;
@class XMPPJID;

NS_SWIFT_NAME(DispatcherHandler)
@protocol XMPPDispatcherHandler <NSObject>
@optional
- (void)didAddConnectionTo:(nonnull XMPPJID *)JID NS_SWIFT_NAME(didAddConnection(_:));
- (void)didRemoveConnectionTo:(nonnull XMPPJID *)JID NS_SWIFT_NAME(didRemoveConnection(_:));
- (void)didConnect:(nonnull XMPPJID *)JID resumed:(BOOL)resumed;
- (void)didDisconnect:(nonnull XMPPJID *)JID;
@end

NS_SWIFT_NAME(IQHandler)
@protocol XMPPIQHandler <NSObject>
- (void)handleIQRequest:(nonnull PXDocument *)document
                timeout:(NSTimeInterval)timeout
             completion:(nullable void (^)(PXDocument *_Nullable response, NSError *_Nullable error))completion;
@end

NS_SWIFT_NAME(MessageHandler)
@protocol XMPPMessageHandler <NSObject>
- (void)handleMessage:(nonnull PXDocument *)document
           completion:(nullable void (^)(NSError *_Nullable error))completion;
@end

NS_SWIFT_NAME(PresenceHandler)
@protocol XMPPPresenceHandler <NSObject>
- (void)handlePresence:(nonnull PXDocument *)document
            completion:(nullable void (^)(NSError *_Nullable error))completion;
@end

NS_SWIFT_NAME(Dispatcher)
@interface XMPPDispatcher : NSObject <XMPPConnectionDelegate, XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

#pragma mark Manage Connections
@property (nonatomic, readonly) NSDictionary *_Nonnull connectionsByJID;
- (void)setConnection:(nonnull id<XMPPConnection>)connection forJID:(nonnull XMPPJID *)JID;
- (void)removeConnectionForJID:(nonnull XMPPJID *)JID;
- (void)removeConnection:(nonnull id<XMPPConnection>)connection;

#pragma mark Manage Handlers
@property (nonatomic, readonly) NSArray<id<XMPPDispatcherHandler>> *_Nonnull dispatcherHandlers;
@property (nonatomic, readonly) NSArray<id<XMPPMessageHandler>> *_Nonnull messageHandlers;
@property (nonatomic, readonly) NSArray<id<XMPPPresenceHandler>> *_Nonnull presenceHandlers;
@property (nonatomic, readonly) NSDictionary<PXQName *, id<XMPPIQHandler>> *_Nonnull IQHandlersByQuery;

- (void)addHandler:(nonnull id)handler;
- (void)addHandler:(nonnull id)handler withIQQueryQNames:(nullable NSArray<PXQName *> *)queryQNames;
- (void)removeHandler:(nonnull id)handler;

#pragma mark Processing
- (NSUInteger)numberOfPendingIQResponses;

@end

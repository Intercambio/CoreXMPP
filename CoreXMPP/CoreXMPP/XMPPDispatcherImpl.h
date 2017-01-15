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

NS_SWIFT_NAME(DispatcherErrorDomain)
extern NSString *_Nonnull const XMPPDispatcherErrorDomain;

typedef NS_ENUM(NSInteger, XMPPDispatcherErrorCode) {
    XMPPDispatcherErrorCodeTimeout,
    XMPPDispatcherErrorCodeNoSender,
    XMPPDispatcherErrorCodeNoRoute,
    XMPPDispatcherErrorCodeInvalidStanza
} NS_SWIFT_NAME(DispatcherErrorCode);

NS_SWIFT_NAME(Handler)
@protocol XMPPHandler
@end

NS_SWIFT_NAME(ConnectionHandler)
@protocol XMPPConnectionHandler <XMPPHandler>
- (void)didConnect:(nonnull XMPPJID *)JID resumed:(BOOL)resumed;
- (void)didDisconnect:(nonnull XMPPJID *)JID;
@end

NS_SWIFT_NAME(IQHandler)
@protocol XMPPIQHandler <XMPPHandler>
- (void)handleIQRequest:(nonnull PXDocument *)document
                timeout:(NSTimeInterval)timeout
             completion:(nullable void (^)(PXDocument *_Nullable response, NSError *_Nullable error))completion;
@end

NS_SWIFT_NAME(MessageHandler)
@protocol XMPPMessageHandler <XMPPHandler>
- (void)handleMessage:(nonnull PXDocument *)document
           completion:(nullable void (^)(NSError *_Nullable error))completion;
@end

NS_SWIFT_NAME(PresenceHandler)
@protocol XMPPPresenceHandler <XMPPHandler>
- (void)handlePresence:(nonnull PXDocument *)document
            completion:(nullable void (^)(NSError *_Nullable error))completion;
@end

NS_SWIFT_NAME(Dispatcher)
@protocol XMPPDispatcher <XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>
- (void)addHandler:(nonnull id<XMPPHandler>)handler;
- (void)addHandler:(nonnull id<XMPPHandler>)handler withIQQueryQNames:(nullable NSArray<PXQName *> *)queryQNames;
- (void)removeHandler:(nonnull id<XMPPHandler>)handler;
@end

@interface XMPPDispatcherImpl : NSObject <XMPPConnectionDelegate, XMPPDispatcher>

#pragma mark Manage Connections
@property (nonatomic, readonly) NSDictionary *_Nonnull connectionsByJID;
- (void)setConnection:(nonnull id<XMPPConnection>)connection forJID:(nonnull XMPPJID *)JID;
- (void)removeConnectionForJID:(nonnull XMPPJID *)JID;
- (void)removeConnection:(nonnull id<XMPPConnection>)connection;

#pragma mark Manage Handlers
@property (nonatomic, readonly) NSArray<id<XMPPConnectionHandler>> *_Nonnull dispatcherHandlers;
@property (nonatomic, readonly) NSArray<id<XMPPMessageHandler>> *_Nonnull messageHandlers;
@property (nonatomic, readonly) NSArray<id<XMPPPresenceHandler>> *_Nonnull presenceHandlers;
@property (nonatomic, readonly) NSDictionary<PXQName *, id<XMPPIQHandler>> *_Nonnull IQHandlersByQuery;

#pragma mark Processing
- (NSUInteger)numberOfPendingIQResponses;

@end

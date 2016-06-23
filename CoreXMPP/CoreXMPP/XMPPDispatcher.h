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

@protocol XMPPDispatcherHandler <NSObject>
@optional
- (void)didAddConnectionTo:(XMPPJID *)JID;
- (void)didRemoveConnectionTo:(XMPPJID *)JID;
- (void)didConnect:(XMPPJID *)JID resumed:(BOOL)resumed;
- (void)didDisconnect:(XMPPJID *)JID;
@end

@protocol XMPPIQHandler <NSObject>
- (void)handleIQRequest:(PXDocument *)document timeout:(NSTimeInterval)timeout completion:(void (^)(PXDocument *response, NSError *error))completion;
@end

@protocol XMPPMessageHandler <NSObject>
- (void)handleMessage:(PXDocument *)document completion:(void (^)(NSError *error))completion;
@end

@protocol XMPPPresenceHandler <NSObject>
- (void)handlePresence:(PXDocument *)document completion:(void (^)(NSError *error))completion;
@end

@interface XMPPDispatcher : NSObject <XMPPConnectionDelegate, XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

#pragma mark Manage Connections
@property (nonatomic, readonly) NSDictionary *connectionsByJID;
- (void)setConnection:(id<XMPPConnection>)connection forJID:(XMPPJID *)JID;
- (void)removeConnectionForJID:(XMPPJID *)JID;
- (void)removeConnection:(id<XMPPConnection>)connection;

#pragma mark Manage Handlers
@property (nonatomic, readonly) NSArray *dispatcherHandlers;
@property (nonatomic, readonly) NSArray *messageHandlers;
@property (nonatomic, readonly) NSArray *presenceHandlers;
@property (nonatomic, readonly) NSDictionary *IQHandlersByQuery;

- (void)addHandler:(id)handler;
- (void)addHandler:(id)handler withIQQueryQNames:(NSArray *)queryQNames;
- (void)removeHandler:(id)handler;

#pragma mark Processing
- (NSUInteger)numberOfPendingIQResponses;

@end

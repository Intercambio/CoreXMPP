//
//  XMPPDispatcher.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PXQName;
@class PXElement;
@class XMPPJID;

@protocol XMPPStanzaHandler <NSObject>
- (void)handleStanza:(PXElement *)stanza completion:(void(^)(NSError *error))completion;
@end

@protocol XMPPConnection <XMPPStanzaHandler>
@property (nonatomic, weak) id<XMPPStanzaHandler> stanzaHandler;
@end

@protocol XMPPIQHandler <NSObject>
- (void)handleIQRequest:(PXElement *)stanza resultHandler:(id<XMPPIQHandler>)resultHandler;
- (void)handleIQResponse:(PXElement *)stanza;
@end

@protocol XMPPMessageHandler <NSObject>
- (void)handleMessage:(PXElement *)stanza completion:(void(^)(NSError *error))completion;
@end

@protocol XMPPPresenceHandler <NSObject>
- (void)handlePresence:(PXElement *)stanza;
@end

@interface XMPPDispatcher : NSObject <XMPPStanzaHandler, XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

#pragma mark Manage Connections
@property (nonatomic, readonly) NSDictionary *connectionsByJID;
- (void)setConnection:(id<XMPPConnection>)connection forJID:(XMPPJID *)JID;
- (void)removeConnectionForJID:(XMPPJID *)JID;
- (void)removeConnection:(id<XMPPConnection>)connection;

#pragma mark Manage Handlers
@property (nonatomic, readonly) NSArray *messageHandlers;
- (void)addMessageHandler:(id<XMPPMessageHandler>)messageHandler;
- (void)removeMessageHandler:(id<XMPPMessageHandler>)messageHandler;

@property (nonatomic, readonly) NSArray *presenceHandlers;
- (void)addPresenceHandler:(id<XMPPPresenceHandler>)presenceHandler;
- (void)removePresenceHandler:(id<XMPPPresenceHandler>)presenceHandler;

@property (nonatomic, readonly) NSDictionary *IQHandlersByQuery;
- (void)setIQHandler:(id<XMPPIQHandler>)handler forQuery:(PXQName *)query;
- (void)removeIQHandlerForQuery:(PXQName *)query;
- (void)removeIQHandler:(id<XMPPIQHandler>)handler;

- (NSUInteger)numberOfPendingIQResponses;

@end

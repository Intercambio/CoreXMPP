//
//  XMPPRouter.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PXQName;
@class PXElement;
@class XMPPModule;
@class XMPPJID;
@class XMPPRouter;

@protocol XMPPStanzaHandler <NSObject>
- (void)handleStanza:(PXElement *)stanza;
@end

@protocol XMPPConnection <XMPPStanzaHandler>
@property (nonatomic, weak) XMPPRouter *router;
@property (nonatomic, readonly) NSArray *JIDs;
@end

@protocol XMPPIQHandler <NSObject>
- (void)handleIQRequest:(PXElement *)stanza resultHandler:(id<XMPPIQHandler>)resultHandler;
- (void)handleIQResponse:(PXElement *)stanza;
@end

@protocol XMPPMessageHandler <NSObject>
- (void)handleMessage:(PXElement *)stanza;
@end

@protocol XMPPPresenceHandler <NSObject>
- (void)handlePresence:(PXElement *)stanza;
@end

@interface XMPPRouter : NSObject <XMPPStanzaHandler, XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

#pragma mark Manage Connections
@property (nonatomic, readonly) NSArray *connections;
- (void)addConnection:(id<XMPPConnection>)connection;
- (void)removeConnection:(id<XMPPConnection>)connection;

- (void)connection:(id<XMPPConnection>)connection didAddRoute:(XMPPJID *)JID;
- (void)connection:(id<XMPPConnection>)connection didRemoveRoute:(XMPPJID *)JID;

#pragma mark Manage Modules
@property (nonatomic, readonly) NSArray *modules;
- (void)addModule:(XMPPModule *)module;
- (void)removeModule:(XMPPModule *)module;

- (void)setModule:(XMPPModule *)module forIQQuery:(PXQName *)query;

@end

//
//  XMPPDispatcher.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

@import Foundation;
@import XMPPFoundation;

#import "XMPPConnection.h"
#import "XMPPDocumentHandler.h"

@class PXQName;

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
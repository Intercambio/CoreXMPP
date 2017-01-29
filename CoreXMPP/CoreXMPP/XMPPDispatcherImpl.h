//
//  XMPPDispatcher.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
//

@import Foundation;
@import XMPPFoundation;

#import "XMPPConnection.h"
#import "XMPPDocumentHandler.h"

@class PXQName;

@protocol XMPPDispatcherDelegate <NSObject>
- (void)dispatcher:(nonnull id<XMPPDispatcher>)dispatcher didReceiveDocument:(nonnull PXDocument *)document;
- (void)dispatcher:(nonnull id<XMPPDispatcher>)dispatcher willSendDocument:(nonnull PXDocument *)document;
@end

@interface XMPPDispatcherImpl : NSObject <XMPPConnectionDelegate, XMPPDispatcher>

@property (nonatomic, readwrite, weak, nullable) id<XMPPDispatcherDelegate> delegate;

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

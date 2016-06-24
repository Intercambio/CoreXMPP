//
//  XMPPConnection.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 26.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDocumentHandler.h"

@protocol XMPPConnection;
@class XMPPJID;

@protocol XMPPConnectionDelegate <XMPPDocumentHandler>
- (void)connection:(id<XMPPConnection>)connection didConnectTo:(XMPPJID *)JID resumed:(BOOL)resumed;
- (void)connection:(id<XMPPConnection>)connection didDisconnectFrom:(XMPPJID *)JID;
@end

@protocol XMPPConnection <XMPPDocumentHandler>
@property (nonatomic, weak) id<XMPPConnectionDelegate> connectionDelegate;
@end

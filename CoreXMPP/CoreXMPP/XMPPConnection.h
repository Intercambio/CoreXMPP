//
//  XMPPConnection.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 26.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanzaHandler.h"

@protocol XMPPConnection;
@class XMPPJID;

@protocol XMPPConnectionDelegate <NSObject>
- (void)connection:(id<XMPPConnection>)connection didConnectTo:(XMPPJID *)JID resumed:(BOOL)resumed;
- (void)connection:(id<XMPPConnection>)connection didDisconnectFrom:(XMPPJID *)JID;
@end

@protocol XMPPConnection <XMPPStanzaHandler>
@property (nonatomic, weak) id<XMPPStanzaHandler> stanzaHandler;
@property (nonatomic, weak) id<XMPPConnectionDelegate> connectionDelegate;
@end

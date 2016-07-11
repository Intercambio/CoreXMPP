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

NS_SWIFT_NAME(ConnectionDelegate)
@protocol XMPPConnectionDelegate <XMPPDocumentHandler>
- (void)connection:(nonnull id<XMPPConnection>)connection didConnectTo:(nonnull XMPPJID *)JID resumed:(BOOL)resumed NS_SWIFT_NAME(connection(_:didConnect:resumed:));
- (void)connection:(nonnull id<XMPPConnection>)connection didDisconnectFrom:(nonnull XMPPJID *)JID NS_SWIFT_NAME(connection(_:didDisconnect:));
@end

NS_SWIFT_NAME(Connection)
@protocol XMPPConnection <XMPPDocumentHandler>
@property (nonatomic, weak) id<XMPPConnectionDelegate> _Nullable connectionDelegate;
@end

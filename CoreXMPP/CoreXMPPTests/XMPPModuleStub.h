//
//  XMPPModuleStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@class PXElement;

@interface XMPPModuleStub : NSObject <XMPPConnectionHandler, XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

- (void)onMessage:(void (^)(XMPPMessageStanza *stanza))callback;
- (void)onPresence:(void (^)(XMPPPresenceStanza *stanza))callback;
- (void)onIQRequest:(void (^)(XMPPIQStanza *stanza, NSTimeInterval timeout, void (^)(XMPPIQStanza *, NSError *)))callback;

- (void)onConnect:(void (^)(XMPPJID *JID, BOOL resumed))callback;
- (void)onDisconnect:(void (^)(XMPPJID *JID))callback;

@end

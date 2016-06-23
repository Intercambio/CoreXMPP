//
//  XMPPModuleStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@class PXElement;

@interface XMPPModuleStub : NSObject <XMPPDispatcherHandler, XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

- (void)onMessage:(void (^)(PXDocument *document))callback;
- (void)onPresence:(void (^)(PXDocument *document))callback;
- (void)onIQRequest:(void (^)(PXDocument *document, NSTimeInterval timeout, void (^)(PXDocument *, NSError *)))callback;

- (void)onAddConnection:(void (^)(XMPPJID *JID))callback;
- (void)onRemoveConnection:(void (^)(XMPPJID *JID))callback;
- (void)onConnect:(void (^)(XMPPJID *JID, BOOL resumed))callback;
- (void)onDisconnect:(void (^)(XMPPJID *JID))callback;

@end

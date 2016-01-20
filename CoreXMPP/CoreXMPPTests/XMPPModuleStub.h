//
//  XMPPModuleStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@class PXElement;

@interface XMPPModuleStub : XMPPModule <XMPPMessageHandler, XMPPPresenceHandler, XMPPIQHandler>

- (void)onMessage:(void (^)(PXElement *stanza))callback;
- (void)onPresence:(void (^)(PXElement *stanza))callback;
- (void)onIQRequest:(void (^)(PXElement *stanza, id<XMPPIQHandler> resultHandler))callback;
- (void)onIQResponse:(void (^)(PXElement *stanza))callback;

- (void)sendIQRequest:(PXElement *)stanza;

@end

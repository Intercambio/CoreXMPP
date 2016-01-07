//
//  XMPPStreamStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

extern NSString * const XMPPStreamStubStreamDidOpenNotification;
extern NSString * const XMPPStreamStubStreamDidCloseNotification;
extern NSString * const XMPPStreamStubStreamDidSendElementNotification;
extern NSString * const XMPPStreamStubStreamNotificationElementKey;

@interface XMPPStreamStub : XMPPStream

#pragma mark Receiving Element
- (void)receiveElement:(PXElement *)element;

#pragma mark Event Handler
- (void)onDidOpen:(void(^)(XMPPStreamStub *stream))handler;
- (void)onDidClose:(void(^)(XMPPStreamStub *stream))handler;
- (void)onDidSendElement:(void(^)(XMPPStreamStub *stream, PXElement *element))handler;

@end

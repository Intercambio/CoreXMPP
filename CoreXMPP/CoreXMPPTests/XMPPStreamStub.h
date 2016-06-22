//
//  XMPPStreamStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

extern NSString *const XMPPStreamStubStreamDidOpenNotification;
extern NSString *const XMPPStreamStubStreamDidCloseNotification;
extern NSString *const XMPPStreamStubStreamDidSendElementNotification;
extern NSString *const XMPPStreamStubStreamNotificationDocumentKey;

@interface XMPPStreamStub : XMPPStream

#pragma mark Receiving Document
- (void)receiveDocument:(PXDocument *)document;

#pragma mark Fail with Error
- (void)failWithError:(NSError *)error;

#pragma mark Close By Peer
- (void)closeByPeer;

#pragma mark Event Handler
- (void)onDidOpen:(void (^)(XMPPStreamStub *stream))handler;
- (void)onDidClose:(void (^)(XMPPStreamStub *stream))handler;
- (void)onDidFail:(void (^)(XMPPStreamStub *stream))handler;
- (void)onDidSendDocument:(void (^)(XMPPStreamStub *stream, PXDocument *document))handler;

@end

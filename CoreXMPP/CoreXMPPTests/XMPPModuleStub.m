//
//  XMPPModuleStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPModuleStub.h"

@interface XMPPModuleStub () {
    dispatch_queue_t _operationQueue;
    NSMutableArray *_onMessageCallbacks;
    NSMutableArray *_onPresenceCallbacks;
    NSMutableArray *_onIQRequestCallbacks;
    NSMutableArray *_onIQResponseCallbacks;
    NSMutableArray *_onAddConnectionCallbacks;
    NSMutableArray *_onRemoveConnectionCallbacks;
    NSMutableArray *_onConnectCallbacks;
    NSMutableArray *_onDisconnectCallbacks;
}

@end

@implementation XMPPModuleStub

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPModuleStub", DISPATCH_QUEUE_SERIAL);
        _onMessageCallbacks = [[NSMutableArray alloc] init];
        _onPresenceCallbacks = [[NSMutableArray alloc] init];
        _onIQRequestCallbacks = [[NSMutableArray alloc] init];
        _onIQResponseCallbacks = [[NSMutableArray alloc] init];
        _onAddConnectionCallbacks = [[NSMutableArray alloc] init];
        _onRemoveConnectionCallbacks = [[NSMutableArray alloc] init];
        _onConnectCallbacks = [[NSMutableArray alloc] init];
        _onDisconnectCallbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark Handler

- (void)handleMessage:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXDocument *) = [_onMessageCallbacks firstObject];
        if (_callback) {
            [_onMessageCallbacks removeObjectAtIndex:0];
            _callback(document);
        }
    });
}

- (void)handlePresence:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXDocument *) = [_onPresenceCallbacks firstObject];
        if (_callback) {
            [_onPresenceCallbacks removeObjectAtIndex:0];
            _callback(document);
        }
    });
}

- (void)handleIQRequest:(PXElement *)stanza timeout:(NSTimeInterval)timeout completion:(void (^)(PXElement *, NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *stanza, NSTimeInterval timeout, void (^)(PXElement *, NSError *)) = [_onIQRequestCallbacks firstObject];
        if (_callback) {
            [_onIQRequestCallbacks removeObjectAtIndex:0];
            _callback(stanza, timeout, completion);
        }
    });
}

- (void)didAddConnectionTo:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPJID *JID) = [_onAddConnectionCallbacks firstObject];
        if (_callback) {
            [_onAddConnectionCallbacks removeObjectAtIndex:0];
            _callback(JID);
        }
    });
}

- (void)didRemoveConnectionTo:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPJID *JID) = [_onRemoveConnectionCallbacks firstObject];
        if (_callback) {
            [_onRemoveConnectionCallbacks removeObjectAtIndex:0];
            _callback(JID);
        }
    });
}

- (void)didConnect:(XMPPJID *)JID resumed:(BOOL)resumed
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPJID *JID, BOOL resumed) = [_onConnectCallbacks firstObject];
        if (_callback) {
            [_onConnectCallbacks removeObjectAtIndex:0];
            _callback(JID, resumed);
        }
    });
}

- (void)didDisconnect:(XMPPJID *)JID
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPJID *JID) = [_onDisconnectCallbacks firstObject];
        if (_callback) {
            [_onDisconnectCallbacks removeObjectAtIndex:0];
            _callback(JID);
        }
    });
}

#pragma mark -

- (void)onMessage:(void (^)(PXDocument *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onMessageCallbacks addObject:callback];
        }
    });
}

- (void)onPresence:(void (^)(PXDocument *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onPresenceCallbacks addObject:callback];
        }
    });
}

- (void)onIQRequest:(void (^)(PXElement *stanza, NSTimeInterval timeout, void (^)(PXElement *, NSError *)))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onIQRequestCallbacks addObject:callback];
        }
    });
}

- (void)onAddConnection:(void (^)(XMPPJID *JID))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onAddConnectionCallbacks addObject:callback];
        }
    });
}

- (void)onRemoveConnection:(void (^)(XMPPJID *JID))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onRemoveConnectionCallbacks addObject:callback];
        }
    });
}

- (void)onConnect:(void (^)(XMPPJID *JID, BOOL resumed))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onConnectCallbacks addObject:callback];
        }
    });
}

- (void)onDisconnect:(void (^)(XMPPJID *JID))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onDisconnectCallbacks addObject:callback];
        }
    });
}

@end

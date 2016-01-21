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
}

@end

@implementation XMPPModuleStub

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPModuleStub", DISPATCH_QUEUE_SERIAL);
        _onMessageCallbacks = [[NSMutableArray alloc] init];
        _onPresenceCallbacks = [[NSMutableArray alloc] init];
        _onIQRequestCallbacks = [[NSMutableArray alloc] init];
        _onIQResponseCallbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark XMPPMessageHandler

- (void)handleMessage:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *) = [_onMessageCallbacks firstObject];
        if (_callback) {
            [_onMessageCallbacks removeObjectAtIndex:0];
            _callback(stanza);
        }
    });
}

- (void)handlePresence:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *) = [_onPresenceCallbacks firstObject];
        if (_callback) {
            [_onPresenceCallbacks removeObjectAtIndex:0];
            _callback(stanza);
        }
    });
}

- (void)handleIQRequest:(PXElement *)stanza resultHandler:(id<XMPPIQHandler>)resultHandler
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *, id<XMPPIQHandler>) = [_onIQRequestCallbacks firstObject];
        if (_callback) {
            [_onIQRequestCallbacks removeObjectAtIndex:0];
            _callback(stanza, resultHandler);
        }
    });
}

- (void)handleIQResponse:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *) = [_onIQResponseCallbacks firstObject];
        if (_callback) {
            [_onIQResponseCallbacks removeObjectAtIndex:0];
            _callback(stanza);
        }
    });
}

#pragma mark -

- (void)onMessage:(void (^)(PXElement *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onMessageCallbacks addObject:callback];
        }
    });
}

- (void)onPresence:(void (^)(PXElement *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onPresenceCallbacks addObject:callback];
        }
    });
}

- (void)onIQRequest:(void (^)(PXElement *stanza, id<XMPPIQHandler> resultHandler))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onIQRequestCallbacks addObject:callback];
        }
    });
}

- (void)onIQResponse:(void (^)(PXElement *stanza))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onIQResponseCallbacks addObject:callback];
        }
    });
}

- (void)sendIQRequest:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        [self.dispatcher handleIQRequest:stanza resultHandler:self];
    });
}

@end

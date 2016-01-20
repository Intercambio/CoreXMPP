//
//  XMPPConnectionStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPConnectionStub.h"

@interface XMPPConnectionStub () {
    dispatch_queue_t _operationQueue;
    NSMutableArray *_onHandleStanzaCallbacks;
    id<XMPPStanzaHandler> _stanzaHandler;
}

@end

@implementation XMPPConnectionStub

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPConnectionStub", DISPATCH_QUEUE_SERIAL);
        _onHandleStanzaCallbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark XMPPConnection

- (void)setStanzaHandler:(id<XMPPStanzaHandler>)stanzaHandler
{
    dispatch_async(_operationQueue, ^{
        _stanzaHandler = stanzaHandler;
    });
}

- (id<XMPPStanzaHandler>)stanzaHandler
{
    __block id<XMPPStanzaHandler> handler = nil;
    dispatch_sync(_operationQueue, ^{
        handler = _stanzaHandler;
    });
    return handler;
}

- (void)handleStanza:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *, id<XMPPStanzaHandler>) = [_onHandleStanzaCallbacks firstObject];
        if (_callback) {
            [_onHandleStanzaCallbacks removeObjectAtIndex:0];
            dispatch_async(dispatch_get_main_queue(), ^{
                _callback(stanza, _stanzaHandler);
            });
        }
    });
}

#pragma mark -

- (void)onHandleStanza:(void (^)(PXElement *, id<XMPPStanzaHandler>))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onHandleStanzaCallbacks addObject:callback];
        }
    });
}

@end

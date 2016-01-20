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
    NSArray *_JIDs;
    XMPPRouter *_router;
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

- (void)setJIDs:(NSArray *)JIDs
{
    dispatch_async(_operationQueue, ^{
        _JIDs = JIDs;
    });
}

- (NSArray *)JIDs
{
    __block NSArray *JIDs = nil;
    dispatch_sync(_operationQueue, ^{
        JIDs = [_JIDs copy];
    });
    return JIDs;
}

- (XMPPRouter *)router
{
    __block XMPPRouter *router = nil;
    dispatch_sync(_operationQueue, ^{
        router = _router;
    });
    return router;
}

- (void)setRouter:(XMPPRouter *)router
{
    dispatch_async(_operationQueue, ^{
        _router = router;
    });
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXElement *) = [_onHandleStanzaCallbacks firstObject];
        if (_callback) {
            [_onHandleStanzaCallbacks removeObjectAtIndex:0];
            dispatch_async(dispatch_get_main_queue(), ^{
                _callback(stanza);
            });
        }
    });
}

#pragma mark -

- (void)onHandleStanza:(void (^)(PXElement *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onHandleStanzaCallbacks addObject:callback];
        }
    });
}

@end

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
}

@end

@implementation XMPPConnectionStub

@synthesize connectionDelegate = _connectionDelegate;

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

- (void)handleDocument:(PXDocument *)document completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) = [_onHandleStanzaCallbacks firstObject];
        if (_callback) {
            [_onHandleStanzaCallbacks removeObjectAtIndex:0];
            dispatch_async(dispatch_get_main_queue(), ^{
                _callback(document, completion, _connectionDelegate);
            });
        } else {
            if (completion) {
                completion(nil);
            }
        }
    });
}

- (void)processPendingDocuments:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if (completion) {
            completion(nil);
        }
    });
}

#pragma mark -

- (void)onHandleDocument:(void (^)(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler))callback;
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onHandleStanzaCallbacks addObject:callback];
        }
    });
}

@end

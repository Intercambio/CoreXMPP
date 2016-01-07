//
//  XMPPStreamStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamStub.h"

NSString * const XMPPStreamStubStreamDidOpenNotification = @"XMPPStreamStubStreamDidOpenNotification";
NSString * const XMPPStreamStubStreamDidCloseNotification = @"XMPPStreamStubStreamDidCloseNotification";
NSString * const XMPPStreamStubStreamDidSendElementNotification = @"XMPPStreamStubStreamDidSendElementNotification";
NSString * const XMPPStreamStubStreamNotificationElementKey = @"XMPPStreamStubStreamNotificationElementKey";

@interface XMPPStreamStub () {
    dispatch_queue_t _operationQueue;
    XMPPStreamState _state;
    NSString *_streamId;
    
    NSMutableArray *_onDidOpenCallbacks;
    NSMutableArray *_onDidCloseCallbacks;
    NSMutableArray *_onDidSendElementCallbacks;
}

@end

@implementation XMPPStreamStub

#pragma mark Life-cycle

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    self = [super initWithHostname:hostname
                           options:options];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPStreamStub", DISPATCH_QUEUE_SERIAL);
        _streamId = [[NSUUID UUID] UUIDString];

        _onDidOpenCallbacks = [[NSMutableArray alloc] init];
        _onDidCloseCallbacks = [[NSMutableArray alloc] init];
        _onDidSendElementCallbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark State

- (XMPPStreamState)state
{
    return _state;
}

- (void)setState:(XMPPStreamState)state
{
    _state = state;
}

#pragma mark Managing Stream

- (void)open
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateClosed, @"Invalid State: Can only open a closed stream.");
        
        _state = XMPPStreamStateOpening;
        
        id<XMPPStreamDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), _operationQueue, ^{
            
            _state = XMPPStreamStateOpen;
            
            dispatch_async(delegateQueue, ^{
                if ([delegate respondsToSelector:@selector(stream:didOpenToHost:withStreamId:)]) {
                    [delegate stream:self didOpenToHost:self.hostname withStreamId:_streamId];
                }
            });
            
            void(^_onDidOpenCallback)(XMPPStreamStub *) = [_onDidOpenCallbacks firstObject];
            if (_onDidOpenCallback) {
                [_onDidOpenCallbacks removeObjectAtIndex:0];
                _onDidOpenCallback(self);
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidOpenNotification
                                                                object:self];
        });
    });
}

- (void)reopen
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only reopen a already opened stream.");
        
        _state = XMPPStreamStateOpening;
        
        id<XMPPStreamDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), _operationQueue, ^{
            
            _state = XMPPStreamStateOpen;
            
            dispatch_async(delegateQueue, ^{
                if ([delegate respondsToSelector:@selector(stream:didOpenToHost:withStreamId:)]) {
                    [delegate stream:self didOpenToHost:self.hostname withStreamId:_streamId];
                }
            });
            
            void(^_onDidOpenCallback)(XMPPStreamStub *) = [_onDidOpenCallbacks firstObject];
            if (_onDidOpenCallback) {
                [_onDidOpenCallbacks removeObjectAtIndex:0];
                _onDidOpenCallback(self);
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidOpenNotification
                                                                object:self];
        });
    });
}

- (void)close
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only close an open stream.");
        
        _state = XMPPStreamStateClosing;
        
        id<XMPPStreamDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), _operationQueue, ^{
            
            _state = XMPPStreamStateClosed;
            
            dispatch_async(delegateQueue, ^{
                if ([delegate respondsToSelector:@selector(streamDidClose:)]) {
                    [delegate streamDidClose:self];
                }
            });
            
            void(^_callback)(XMPPStreamStub *) = [_onDidCloseCallbacks firstObject];
            if (_callback) {
                [_onDidCloseCallbacks removeObjectAtIndex:0];
                _callback(self);
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidCloseNotification
                                                                object:self];
        });
    });
}

#pragma mark Sending Element

- (void)sendElement:(PXElement *)element
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only send an element if the stream is open.");
        
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidSendElementNotification
                                                            object:self
                                                          userInfo:@{ XMPPStreamStubStreamNotificationElementKey: element }];
        
        void(^_callback)(XMPPStreamStub *, PXElement *) = [_onDidSendElementCallbacks firstObject];
        if (_callback) {
            [_onDidSendElementCallbacks removeObjectAtIndex:0];
            _callback(self, element);
        }
        
    });
}

#pragma mark Receiving Element

- (void)receiveElement:(PXElement *)element
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only receive an element if the stream is open.");
        
        
        id<XMPPStreamDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(stream:didReceiveElement:)]) {
                [delegate stream:self didReceiveElement:element];
            }
        });
        
    });
}

#pragma mark Event Handler

- (void)onDidOpen:(void(^)(XMPPStreamStub *stream))handler
{
    if (handler) {
        dispatch_async(_operationQueue, ^{
            [_onDidOpenCallbacks addObject:handler];
        });
    }
}

- (void)onDidClose:(void(^)(XMPPStreamStub *stream))handler
{
    if (handler) {
        dispatch_async(_operationQueue, ^{
            [_onDidCloseCallbacks addObject:handler];
        });
    }
}

- (void)onDidSendElement:(void(^)(XMPPStreamStub *stream, PXElement *element))handler
{
    if (handler) {
        dispatch_async(_operationQueue, ^{
            [_onDidSendElementCallbacks addObject:handler];
        });
    }
}

@end

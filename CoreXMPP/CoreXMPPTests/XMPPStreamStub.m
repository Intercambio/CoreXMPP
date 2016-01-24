//
//  XMPPStreamStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamStub.h"

NSString *const XMPPStreamStubStreamDidOpenNotification = @"XMPPStreamStubStreamDidOpenNotification";
NSString *const XMPPStreamStubStreamDidCloseNotification = @"XMPPStreamStubStreamDidCloseNotification";
NSString *const XMPPStreamStubStreamDidSendElementNotification = @"XMPPStreamStubStreamDidSendElementNotification";
NSString *const XMPPStreamStubStreamNotificationElementKey = @"XMPPStreamStubStreamNotificationElementKey";

@interface XMPPStreamStub () {
    XMPPStreamState _state;
    NSString *_streamId;
    
    NSMutableArray *_onDidOpenCallbacks;
    NSMutableArray *_onDidCloseCallbacks;
    NSMutableArray *_onDidFailCallbacks;
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
        _streamId = [[NSUUID UUID] UUIDString];
        
        _onDidOpenCallbacks = [[NSMutableArray alloc] init];
        _onDidCloseCallbacks = [[NSMutableArray alloc] init];
        _onDidFailCallbacks = [[NSMutableArray alloc] init];
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
    NSAssert(_state == XMPPStreamStateClosed, @"Invalid State: Can only open a closed stream.");
    
    _state = XMPPStreamStateOpening;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), [self xmpp_queue], ^{
        
        _state = XMPPStreamStateOpen;
        
        if ([self.delegate respondsToSelector:@selector(stream:didOpenToHost:withStreamId:)]) {
            [self.delegate stream:self didOpenToHost:self.hostname withStreamId:_streamId];
        }
        
        void (^_onDidOpenCallback)(XMPPStreamStub *) = [_onDidOpenCallbacks firstObject];
        if (_onDidOpenCallback) {
            [_onDidOpenCallbacks removeObjectAtIndex:0];
            _onDidOpenCallback(self);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidOpenNotification
                                                            object:self];
    });
}

- (void)reopen
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only reopen a already opened stream.");
    
    _state = XMPPStreamStateOpening;
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), [self xmpp_queue], ^{
        
        _state = XMPPStreamStateOpen;
        
        if ([self.delegate respondsToSelector:@selector(stream:didOpenToHost:withStreamId:)]) {
            [self.delegate stream:self didOpenToHost:self.hostname withStreamId:_streamId];
        }
        
        void (^_onDidOpenCallback)(XMPPStreamStub *) = [_onDidOpenCallbacks firstObject];
        if (_onDidOpenCallback) {
            [_onDidOpenCallbacks removeObjectAtIndex:0];
            _onDidOpenCallback(self);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidOpenNotification
                                                            object:self];
    });
}

- (void)close
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only close an open stream.");
    
    _state = XMPPStreamStateClosing;
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), [self xmpp_queue], ^{
        
        _state = XMPPStreamStateClosed;
        
        if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
            [self.delegate streamDidClose:self];
        }
        
        void (^_callback)(XMPPStreamStub *) = [_onDidCloseCallbacks firstObject];
        if (_callback) {
            [_onDidCloseCallbacks removeObjectAtIndex:0];
            _callback(self);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidCloseNotification
                                                            object:self];
    });
}

#pragma mark Sending Element

- (void)sendElement:(PXElement *)element
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only send an element if the stream is open.");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidSendElementNotification
                                                        object:self
                                                      userInfo:@{XMPPStreamStubStreamNotificationElementKey : element}];
    
    void (^_callback)(XMPPStreamStub *, PXElement *) = [_onDidSendElementCallbacks firstObject];
    if (_callback) {
        [_onDidSendElementCallbacks removeObjectAtIndex:0];
        _callback(self, element);
    }
}

#pragma mark Receiving Element

- (void)receiveElement:(PXElement *)element
{
    dispatch_async([self xmpp_queue], ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only receive an element if the stream is open.");
        
        if ([self.delegate respondsToSelector:@selector(stream:didReceiveElement:)]) {
            [self.delegate stream:self didReceiveElement:element];
        }
    });
}

#pragma mark Fail with Error

- (void)failWithError:(NSError *)error
{
    dispatch_async([self xmpp_queue], ^{
        
        _state = XMPPStreamStateClosed;
        
        
        if ([self.delegate respondsToSelector:@selector(stream:didFailWithError:)]) {
            [self.delegate stream:self didFailWithError:error];
        }
        
        void (^_callback)(XMPPStreamStub *) = [_onDidFailCallbacks firstObject];
        if (_callback) {
            [_onDidFailCallbacks removeObjectAtIndex:0];
            _callback(self);
        }
    });
}

#pragma mark Close By Peer

- (void)closeByPeer
{
    dispatch_async([self xmpp_queue], ^{
        
        _state = XMPPStreamStateClosed;
        
        if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
            [self.delegate streamDidClose:self];
        }
    });
}

#pragma mark Event Handler

- (void)onDidOpen:(void (^)(XMPPStreamStub *stream))handler
{
    if (handler) {
        [_onDidOpenCallbacks addObject:handler];
    }
}

- (void)onDidClose:(void (^)(XMPPStreamStub *stream))handler
{
    if (handler) {
        [_onDidCloseCallbacks addObject:handler];
    }
}

- (void)onDidSendElement:(void (^)(XMPPStreamStub *stream, PXElement *element))handler
{
    if (handler) {
        [_onDidSendElementCallbacks addObject:handler];
    }
}

- (void)onDidFail:(void (^)(XMPPStreamStub *))handler
{
    if (handler) {
        [_onDidFailCallbacks addObject:handler];
    }
}

#pragma mark Queue

- (dispatch_queue_t)xmpp_queue
{
    return self.queue ?: dispatch_get_main_queue();
}

@end

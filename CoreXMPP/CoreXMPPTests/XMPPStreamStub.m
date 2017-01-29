//
//  XMPPStreamStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 07.01.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
//

#import "XMPPStreamStub.h"

NSString *const XMPPStreamStubStreamDidOpenNotification = @"XMPPStreamStubStreamDidOpenNotification";
NSString *const XMPPStreamStubStreamDidCloseNotification = @"XMPPStreamStubStreamDidCloseNotification";
NSString *const XMPPStreamStubStreamDidSendElementNotification = @"XMPPStreamStubStreamDidSendElementNotification";
NSString *const XMPPStreamStubStreamNotificationDocumentKey = @"XMPPStreamStubStreamNotificationDocumentKey";

@interface XMPPStreamStub () {
    XMPPStreamState _state;
    NSString *_streamId;

    NSMutableArray *_onDidOpenCallbacks;
    NSMutableArray *_onDidCloseCallbacks;
    NSMutableArray *_onDidFailCallbacks;
    NSMutableArray *_onDidSendDocumentCallbacks;
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
        _onDidSendDocumentCallbacks = [[NSMutableArray alloc] init];
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

- (void)suspend
{
    _state = XMPPStreamStateClosed;

    if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
        [self.delegate streamDidClose:self];
    }
}

#pragma mark Sending Element

- (void)sendDocument:(PXDocument *)document
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only send an element if the stream is open.");

    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPStreamStubStreamDidSendElementNotification
                                                        object:self
                                                      userInfo:@{XMPPStreamStubStreamNotificationDocumentKey : document}];

    void (^_callback)(XMPPStreamStub *, PXDocument *) = [_onDidSendDocumentCallbacks firstObject];
    if (_callback) {
        [_onDidSendDocumentCallbacks removeObjectAtIndex:0];
        _callback(self, document);
    }
}

#pragma mark Receiving Document

- (void)receiveDocument:(PXDocument *)document
{
    dispatch_async([self xmpp_queue], ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only receive an element if the stream is open.");

        if ([self.delegate respondsToSelector:@selector(stream:didReceiveDocument:)]) {
            [self.delegate stream:self didReceiveDocument:document];
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

- (void)onDidSendDocument:(void (^)(XMPPStreamStub *stream, PXDocument *document))handler
{
    if (handler) {
        [_onDidSendDocumentCallbacks addObject:handler];
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

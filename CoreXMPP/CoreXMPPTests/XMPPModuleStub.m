//
//  XMPPModuleStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
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

- (void)handleMessage:(XMPPMessageStanza *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPMessageStanza *) = [_onMessageCallbacks firstObject];
        if (_callback) {
            [_onMessageCallbacks removeObjectAtIndex:0];
            _callback(stanza);
        }
    });
}

- (void)handlePresence:(XMPPPresenceStanza *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPPresenceStanza *) = [_onPresenceCallbacks firstObject];
        if (_callback) {
            [_onPresenceCallbacks removeObjectAtIndex:0];
            _callback(stanza);
        }
    });
}

- (void)handleIQRequest:(XMPPIQStanza *)stanza timeout:(NSTimeInterval)timeout completion:(void (^)(XMPPIQStanza *, NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        void (^_callback)(XMPPIQStanza *, NSTimeInterval, void (^)(XMPPIQStanza *, NSError *)) = [_onIQRequestCallbacks firstObject];
        if (_callback) {
            [_onIQRequestCallbacks removeObjectAtIndex:0];
            _callback(stanza, timeout, completion);
        }
    });
}

- (void)didConnect:(XMPPJID *)JID resumed:(BOOL)resumed features:(nullable NSArray<XMPPFeature *> *)features
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

- (void)onMessage:(void (^)(XMPPMessageStanza *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onMessageCallbacks addObject:callback];
        }
    });
}

- (void)onPresence:(void (^)(XMPPPresenceStanza *))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onPresenceCallbacks addObject:callback];
        }
    });
}

- (void)onIQRequest:(void (^)(XMPPIQStanza *, NSTimeInterval, void (^)(XMPPIQStanza *, NSError *)))callback
{
    dispatch_async(_operationQueue, ^{
        if (callback) {
            [_onIQRequestCallbacks addObject:callback];
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

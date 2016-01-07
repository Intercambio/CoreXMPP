//
//  XMPPClient.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPWebsocketStream.h"

#import "XMPPClient.h"

NSString * const XMPPClientOptionsStreamKey = @"XMPPClientOptionsStreamKey";

@interface XMPPClient () <XMPPStreamDelegate> {
    dispatch_queue_t _operationQueue;
    XMPPClientState _state;
    XMPPWebsocketStream *_stream;
}

@end

@implementation XMPPClient

#pragma mark Life-cycle

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _operationQueue = dispatch_queue_create("XMPPClient", DISPATCH_QUEUE_SERIAL);
        _state = XMPPClientStateDisconnected;
        
        _stream = options[XMPPClientOptionsStreamKey] ?: [[XMPPWebsocketStream alloc] initWithHostname:hostname options:options];
        _stream.delegateQueue = _operationQueue;
        _stream.delegate = self;

    }
    return self;
}

#pragma mark Properties

- (NSString *)hostname
{
    return _stream.hostname;
}

- (NSDictionary *)options
{
    return _stream.options;
}

#pragma mark Manage Client

- (void)connect
{
    dispatch_async(_operationQueue, ^{
        
    });
}

- (void)disconnect
{
    dispatch_async(_operationQueue, ^{
        
    });
}

#pragma mark Sending Stanza

- (void)sendStanza:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        
    });
}

#pragma mark XMPPStreamDelegate

- (void)stream:(XMPPStream *)stream didOpenToHost:(NSString *)hostname withStreamId:(NSString *)streamId
{
}

- (void)stream:(XMPPStream *)stream didReceiveElement:(PXElement *)element
{
}

- (void)stream:(XMPPStream *)stream didFailWithError:(NSError *)error
{
}

- (void)streamDidClose:(XMPPStream *)stream
{
}

@end

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
        NSAssert(_state == XMPPClientStateDisconnected, @"Invalid State: Can only connect a disconnected client.");
        _state = XMPPClientStateConnecting;
        [_stream open];
    });
}

- (void)disconnect
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPClientStateEstablished, @"Invalid State: Can only disconnect a client with an established connection.");
        _state = XMPPClientStateDisconnecting;
        [_stream close];
    });
}

#pragma mark Sending Stanza

- (void)sendStanza:(PXElement *)stanza
{
    dispatch_async(_operationQueue, ^{
        
    });
}

#pragma mark Feature Negotiation

- (void)beginNegotiationWithElement:(PXElement *)element
{
    _state = XMPPClientStateNegotiating;
    
    NSMutableArray *mandatoryFeatures = [[NSMutableArray alloc] init];
    NSMutableArray *voluntaryFeatures = [[NSMutableArray alloc] init];
    
    [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
        
    }];
    
    if ([mandatoryFeatures count] > 0) {
        
        // Mandatory features are left for negotiation
        
    } else if ([voluntaryFeatures count] > 0 ) {
    
        // Only voluntary features are left for negotiation
        
    } else {
        
        // No features left to negotiate
        // The connection is established
        
        _state = XMPPClientStateEstablished;
        
        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(clientDidConnect:)]) {
                [delegate clientDidConnect:self];
            }
        });
    }
}

#pragma mark XMPPStreamDelegate

- (void)stream:(XMPPStream *)stream didOpenToHost:(NSString *)hostname withStreamId:(NSString *)streamId
{
    _state = XMPPClientStateConnected;
}

- (void)stream:(XMPPStream *)stream didReceiveElement:(PXElement *)element
{
    if (_state == XMPPClientStateConnected) {
        
        // Expecting a features element to start the negoatiation
        
        if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
            [element.name isEqualToString:@"features"]) {
            
            [self beginNegotiationWithElement:element];
            
        } else {
            // Unexpected element
            _state = XMPPClientStateDisconnecting;
            [_stream close];
        }
        
    } else if (_state == XMPPClientStateNegotiating) {
        
    } else if (_state == XMPPClientStateEstablished) {
        
    } else {
        
    }
}

- (void)stream:(XMPPStream *)stream didFailWithError:(NSError *)error
{
    _state = XMPPClientStateDisconnected;
}

- (void)streamDidClose:(XMPPStream *)stream
{
    _state = XMPPClientStateDisconnected;
    
    id<XMPPClientDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(delegateQueue, ^{
        if ([delegate respondsToSelector:@selector(clientDidDisconnect:)]) {
            [delegate clientDidDisconnect:self];
        }
    });
}

@end

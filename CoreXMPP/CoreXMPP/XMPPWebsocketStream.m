//
//  XMPPWebsocketStream.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. 
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

#import <SocketRocket/SRWebSocket.h>

#import "XMPPError.h"
#import "XMPPWebsocketStream.h"

NSString *const XMPPWebsocketStreamURLKey = @"XMPPWebsocketStreamURLKey";
NSString *const XMPPWebsocketStream_NS = @"urn:ietf:params:xml:ns:xmpp-framing";

@interface XMPPWebsocketStream () <SRWebSocketDelegate> {
    XMPPStreamState _state;
    SRWebSocket *_websocket;
    NSURL *_discoveredWebsocketURL;
}

@end

@implementation XMPPWebsocketStream

#pragma mark Life-cycle

- (void)dealloc
{
    [self xmpp_tearDownWebsocket];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<XMPPWebsocketStream %p (%@)>", self, [self xmpp_websocketURL]];
}

#pragma mark State

- (XMPPStreamState)state
{
    return _state;
}

#pragma mark Managing Stream

- (void)open
{
    NSAssert(_state == XMPPStreamStateClosed, @"Invalid State: Can only open a closed stream.");

    NSLog(@"Open stream to host: %@", self.hostname);

    if ([self xmpp_needsDiscoverWebsocketURL]) {
        [self xmpp_discoverWebsocketURL];
        _state = XMPPStreamStateDiscovering;
    } else {
        [self xmpp_setUpWebsocket];
        [_websocket open];
        _state = XMPPStreamStateConnecting;
        NSLog(@"Connecting to host: %@ (%@)", self.hostname, _websocket.url);
    }
}

- (void)reopen
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only reopen a already opened stream.");

    NSLog(@"Repoen stream to host: %@", self.hostname);

    [self xmpp_sendOpenFrame];
    _state = XMPPStreamStateOpening;
}

- (void)close
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only close an open stream.");

    NSLog(@"Close stream to host: %@", self.hostname);

    [self xmpp_sendCloseFrame];
    _state = XMPPStreamStateClosing;
}

- (void)suspend
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only suspend an open stream.");

    NSLog(@"Suspending stream to host: %@", self.hostname);

    [self xmpp_tearDownWebsocket];
    _state = XMPPStreamStateClosed;

    if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
        [self.delegate streamDidClose:self];
    }
}

#pragma mark Sending Document

- (void)sendDocument:(PXDocument *)document
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only send an element if the stream is open.");
    [self xmpp_sendDocument:document];
}

#pragma mark -

#pragma mark Framing

- (void)xmpp_sendOpenFrame
{
    PXDocument *openFrameDocument = [[PXDocument alloc] initWithElementName:@"open"
                                                                  namespace:XMPPWebsocketStream_NS
                                                                     prefix:nil];
    [openFrameDocument.root setValue:self.hostname forAttribute:@"to"];
    [openFrameDocument.root setValue:@"1.0" forAttribute:@"version"];

    NSLog(@"Send open frame.");

    [self xmpp_sendDocument:openFrameDocument];
}

- (void)xmpp_sendCloseFrame
{
    PXDocument *closeFrameDocument = [[PXDocument alloc] initWithElementName:@"close"
                                                                   namespace:XMPPWebsocketStream_NS
                                                                      prefix:nil];
    NSLog(@"Send close frame.");

    [self xmpp_sendDocument:closeFrameDocument];
}

- (void)xmpp_handleFrameDocument:(PXDocument *)document
{
    if ([[document.root name] isEqualToString:@"open"]) {
        [self xmpp_handleOpenFrame:document];
    } else if ([[document.root name] isEqualToString:@"close"]) {
        [self xmpp_handleCloseFrame:document];
    } else {
        NSString *errorMessage = @"Recevied unsupported framing document.";

        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorMessage};
        NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeInvalidState
                                         userInfo:userInfo];
        [self xmpp_handleError:error];
    }
}

- (void)xmpp_handleOpenFrame:(PXDocument *)document
{
    NSLog(@"Received open frame: %@", document);

    if (_state != XMPPStreamStateOpening) {

        NSString *errorMessage = @"Received unexpected open frame.";

        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorMessage};
        NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeInvalidState
                                         userInfo:userInfo];

        [self xmpp_handleError:error];

    } else {

        NSString *hostname = [document.root valueForAttribute:@"from"];
        NSString *streamId = [document.root valueForAttribute:@"id"];

        _state = XMPPStreamStateOpen;

        if ([self.delegate respondsToSelector:@selector(stream:didOpenToHost:withStreamId:)]) {
            [self.delegate stream:self didOpenToHost:hostname withStreamId:streamId];
        }
    }
}

- (void)xmpp_handleCloseFrame:(PXDocument *)document
{
    NSLog(@"Received close frame: %@", document);

    if (_state != XMPPStreamStateOpen && _state != XMPPStreamStateClosing) {

        NSString *errorMessage = @"Received unexpected close frame.";

        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorMessage};
        NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeInvalidState
                                         userInfo:userInfo];

        [self xmpp_handleError:error];

    } else {

        if (_state == XMPPStreamStateOpen) {
            [self xmpp_sendCloseFrame];
        }

        _state = XMPPStreamStateDisconnecting;
        [_websocket close];
    }
}

#pragma mark Sending & Receiving Documents

- (void)xmpp_sendDocument:(PXDocument *)document
{
    NSString *message = [[self class] stringFromDocument:document];
    NSError *error = nil;
    BOOL success = [_websocket sendString:message error:&error];
    if (!success) {
        NSLog(@"Failed to send message: %@", [error localizedDescription]);
    }
}

- (void)xmpp_handleDocument:(PXDocument *)document
{
    if ([[document.root namespace] isEqualToString:XMPPWebsocketStream_NS]) {
        [self xmpp_handleFrameDocument:document];
    } else {
        if (_state != XMPPStreamStateOpen) {
            NSLog(@"Can only handle elements other than framing elements if the stream is open. Dropping received element. Current state is %lu and the received document is: %@", (unsigned long)_state, document);
        } else {
            if ([self.delegate respondsToSelector:@selector(stream:didReceiveDocument:)]) {
                [self.delegate stream:self didReceiveDocument:document];
            }
        }
    }
}

#pragma Keep Alive

- (void)keepAlive
{
    NSTimeInterval keepAliveInterval = 20.0;
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(keepAliveInterval * NSEC_PER_SEC)), [self xmpp_queue], ^{
        if (_self && _websocket.readyState == SR_OPEN) {
            NSError *error = nil;
            BOOL success = [_websocket sendPing:nil error:&error];
            if (!success) {
                NSLog(@"Failed to send ping: %@", [error localizedDescription]);
            }
            [_self keepAlive];
        }
    });
}

#pragma mark Error Handling

- (void)xmpp_handleError:(NSError *)error
{
    NSLog(@"Stream to host '%@' did fail with error: %@", self.hostname, [error localizedDescription]);

    [self xmpp_tearDownWebsocket];
    _state = XMPPStreamStateClosed;

    if ([self.delegate respondsToSelector:@selector(stream:didFailWithError:)]) {
        [self.delegate stream:self didFailWithError:error];
    }
}

#pragma mark Manage Websocket

- (NSURL *)xmpp_websocketURL
{
    NSURL *websocketURL = self.options[XMPPWebsocketStreamURLKey];
    if (websocketURL == nil) {
        return _discoveredWebsocketURL;
    }
    return websocketURL;
}

- (void)xmpp_setUpWebsocket
{
    NSAssert(_websocket == nil, @"Invalid State: Websocket is already set up.");

    NSURL *websocketURL = [self xmpp_websocketURL];
    NSLog(@"Setup Websocket with URL: %@", websocketURL);

    SRWebSocket *websocket = [[SRWebSocket alloc] initWithURL:websocketURL
                                                    protocols:@[ @"xmpp" ]
                               allowsUntrustedSSLCertificates:YES];

    [websocket setDelegateDispatchQueue:[self xmpp_queue]];
    websocket.delegate = self;

    _websocket = websocket;
}

- (void)xmpp_tearDownWebsocket
{
    _websocket.delegate = nil;
    [_websocket close];
    _websocket = nil;
    _discoveredWebsocketURL = nil;
}

#pragma mark Discovering

- (BOOL)xmpp_needsDiscoverWebsocketURL
{
    return _discoveredWebsocketURL == nil && self.options[XMPPWebsocketStreamURLKey] == nil;
}

- (void)xmpp_discoverWebsocketURL
{
    NSLog(@"Discovering websocket URL for host: %@", self.hostname);

    NSURLComponents *hostMetadataURLComponents = [[NSURLComponents alloc] init];
    hostMetadataURLComponents.scheme = @"https";
    hostMetadataURLComponents.host = self.hostname;
    hostMetadataURLComponents.path = @"/.well-known/host-meta";

    NSURL *hostMetadataURL = [hostMetadataURLComponents URL];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:hostMetadataURL];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                                     dispatch_async([self xmpp_queue], ^{
                                                                         if (error) {
                                                                             [self xmpp_handleError:error];
                                                                         } else {
                                                                             [self xmpp_handleDiscoveryResponseData:data];
                                                                         }
                                                                     });
                                                                 }];
    [task resume];
}

- (void)xmpp_handleDiscoveryResponseData:(NSData *)data
{
    __block NSURL *websocketURL = nil;

    if (data) {
        PXDocument *hostMetadata = [PXDocument documentWithData:data];
        if ([hostMetadata.root isEqual:PXQN(@"http://docs.oasis-open.org/ns/xri/xrd-1.0", @"XRD")]) {
            [hostMetadata.root enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
                if ([element isEqual:PXQN(@"http://docs.oasis-open.org/ns/xri/xrd-1.0", @"Link")] &&
                    [[element valueForAttribute:@"rel"] isEqual:@"urn:xmpp:alt-connections:websocket"]) {
                    NSString *websocketURLString = [element valueForAttribute:@"href"];
                    websocketURL = websocketURLString ? [NSURL URLWithString:websocketURLString] : nil;
                }
            }];
        }
    }

    if (websocketURL) {
        _discoveredWebsocketURL = websocketURL;
        _state = XMPPStreamStateConnecting;

        [self xmpp_setUpWebsocket];
        [_websocket open];

    } else {
        NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeDiscoveryError
                                         userInfo:nil];
        [self xmpp_handleError:error];
    }
}

#pragma mark Operation Queue

- (dispatch_queue_t)xmpp_queue
{
    return self.queue ?: dispatch_get_main_queue();
}

#pragma mark - SRWebSocketDelegate (called on [self xmpp_queue])

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    if (_state != XMPPStreamStateConnecting) {
        NSString *errorMessage = @"Expecting stream to be in state 'connection' while the connection is established.";
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorMessage};
        NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeInvalidState
                                         userInfo:userInfo];
        [self xmpp_handleError:error];
    } else {
        _state = XMPPStreamStateOpening;
        [self xmpp_sendOpenFrame];
        [self keepAlive];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSData *messageData = nil;

    if ([message isKindOfClass:[NSString class]]) {
        messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([message isKindOfClass:[NSData class]]) {
        messageData = message;
    }

//    NSLog(@"IN <<< %@", messageData ? [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding] : @"<no string or data>");

    if (messageData) {
        PXDocument *document = [PXDocument documentWithData:messageData];

        if (document) {
            [self xmpp_handleDocument:document];
        } else {

            NSString *errorMessage = @"Failed to parse received XML document.";

            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorMessage};
            NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                                 code:XMPPErrorCodeParseError
                                             userInfo:userInfo];

            [self xmpp_handleError:error];
        }

    } else {

        NSString *errorMessage = [NSString stringWithFormat:@"Received websocket message of wrong format. Expected UTF8 encoded string or data. Got `%@`", NSStringFromClass([message class])];

        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorMessage};
        NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                             code:XMPPErrorCodeMessageFormatError
                                         userInfo:userInfo];

        [self xmpp_handleError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (_state == XMPPStreamStateDisconnecting) {
        [self xmpp_tearDownWebsocket];
        _state = XMPPStreamStateClosed;
        if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
            [self.delegate streamDidClose:self];
        }
    } else {
        [self xmpp_handleError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self xmpp_tearDownWebsocket];
    _state = XMPPStreamStateClosed;

    if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
        [self.delegate streamDidClose:self];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
}

#pragma mark - Helpers

+ (NSString *)stringFromDocument:(PXDocument *)document
{
    NSString *documentString = [[NSString alloc] initWithData:[document data]
                                                     encoding:NSUTF8StringEncoding];

    if ([documentString hasPrefix:@"<?xml"]) {
        // Strip XML decleration
        NSRange range = [documentString rangeOfString:@"?>"];
        documentString = [documentString substringFromIndex:NSMaxRange(range)];
        documentString = [documentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    return documentString;
}

@end

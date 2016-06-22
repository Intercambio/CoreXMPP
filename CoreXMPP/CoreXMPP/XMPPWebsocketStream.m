//
//  XMPPWebsocketStream.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <SocketRocket/SRWebSocket.h>

#import "XMPPError.h"
#import "XMPPWebsocketStream.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPWebsocketStreamURLKey = @"XMPPWebsocketStreamURLKey";
NSString *const XMPPWebsocketStream_NS = @"urn:ietf:params:xml:ns:xmpp-framing";

@interface XMPPWebsocketStream () <SRWebSocketDelegate> {
    XMPPStreamState _state;
    SRWebSocket *_websocket;
    NSURL *_discoveredWebsocketURL;
}

@end

@implementation XMPPWebsocketStream

#pragma mark Logging

+ (DDLogLevel)ddLogLevel
{
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel
{
    ddLogLevel = logLevel;
}

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

    DDLogInfo(@"Open stream to host: %@", self.hostname);

    if ([self xmpp_needsDiscoverWebsocketURL]) {
        [self xmpp_discoverWebsocketURL];
        _state = XMPPStreamStateDiscovering;
    } else {
        [self xmpp_setUpWebsocket];
        [_websocket open];
        _state = XMPPStreamStateConnecting;
        DDLogInfo(@"Connecting to host: %@ (%@)", self.hostname, _websocket.url);
    }
}

- (void)reopen
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only reopen a already opened stream.");

    DDLogInfo(@"Repoen stream to host: %@", self.hostname);

    [self xmpp_sendOpenFrame];
    _state = XMPPStreamStateOpening;
}

- (void)close
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only close an open stream.");

    DDLogInfo(@"Close stream to host: %@", self.hostname);

    [self xmpp_sendCloseFrame];
    _state = XMPPStreamStateClosing;
}

- (void)suspend
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only suspend an open stream.");

    DDLogInfo(@"Suspending stream to host: %@", self.hostname);

    [self xmpp_tearDownWebsocket];
    _state = XMPPStreamStateClosed;

    if ([self.delegate respondsToSelector:@selector(streamDidClose:)]) {
        [self.delegate streamDidClose:self];
    }
}

#pragma mark Sending Element

- (void)sendElement:(PXElement *)element
{
    NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only send an element if the stream is open.");
    PXDocument *document = [[PXDocument alloc] initWithElement:element];
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

    DDLogDebug(@"Send open frame.");

    [self xmpp_sendDocument:openFrameDocument];
}

- (void)xmpp_sendCloseFrame
{
    PXDocument *closeFrameDocument = [[PXDocument alloc] initWithElementName:@"close"
                                                                   namespace:XMPPWebsocketStream_NS
                                                                      prefix:nil];
    DDLogDebug(@"Send close frame.");

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
    DDLogVerbose(@"Received open frame: %@", document);

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
    DDLogVerbose(@"Received close frame: %@", document);

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
    DDLogVerbose(@"OUT >>> %@", message);
    [_websocket send:message];
}

- (void)xmpp_handleDocument:(PXDocument *)document
{
    if ([[document.root namespace] isEqualToString:XMPPWebsocketStream_NS]) {
        [self xmpp_handleFrameDocument:document];
    } else {
        if (_state != XMPPStreamStateOpen) {
            DDLogWarn(@"Can only handle elements other than framing elements if the stream is open. Dropping received element. Current state is %lu and the received document is: %@", (unsigned long)_state, document);
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
            [_websocket sendPing:nil];
            [_self keepAlive];
        }
    });
}

#pragma mark Error Handling

- (void)xmpp_handleError:(NSError *)error
{
    DDLogError(@"Stream to host '%@' did fail with error: %@", self.hostname, [error localizedDescription]);

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
    DDLogDebug(@"Setup Websocket with URL: %@", websocketURL);

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
    DDLogInfo(@"Discovering websocket URL for host: %@", self.hostname);

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

    DDLogVerbose(@"IN <<< %@", messageData ? [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding] : @"<no string or data>");

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

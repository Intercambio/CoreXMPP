//
//  XMPPWebsocketStream.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <SocketRocket/SRWebSocket.h>

#import "XMPPWebsocketStream.h"

NSString *const XMPPWebsocketStreamURLKey = @"XMPPWebsocketStreamURLKey";
NSString *const XMPPWebsocketStream_NS = @"urn:ietf:params:xml:ns:xmpp-framing";

@interface XMPPWebsocketStream () <SRWebSocketDelegate> {
    dispatch_queue_t _operationQueue;
    XMPPStreamState _state;
    SRWebSocket *_websocket;
}
@property (nonatomic, readwrite) XMPPStreamState state;
@end

@implementation XMPPWebsocketStream

#pragma mark Life-cycle

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    self = [super initWithHostname:hostname
                           options:options];
    if (self) {
        NSString *queueName = [NSString stringWithFormat:@"XMPPWebsocketStream Operation Queue (%@)", hostname];
        _operationQueue = dispatch_queue_create([queueName UTF8String],
                                                DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc
{
    if (_websocket) {
        _websocket.delegate = nil;
        [_websocket close];
        _websocket = nil;
    }
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<XMPPWebsocketStream %p (%@)>", self, [self websocketURL]];
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

        [self setUpWebsocket];
        [_websocket open];

        self.state = XMPPStreamStateConnecting;
    });
}

- (void)reopen
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only reopen a already opened stream.");

        [self sendOpenFrame];
        self.state = XMPPStreamStateOpening;
    });
}

- (void)close
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only close an open stream.");

        [self sendCloseFrame];
        self.state = XMPPStreamStateClosing;
    });
}

#pragma mark Sending Element

- (void)sendElement:(PXElement *)element
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPStreamStateOpen, @"Invalid State: Can only send an element if the stream is open.");

        PXDocument *document = [[PXDocument alloc] initWithElement:element];
        NSString *message = [[self class] stringFromDocument:document];
#ifdef DEBUG
        NSLog(@"%@ OUT >>> %@", self, message);
#endif
        [_websocket send:message];
    });
}

#pragma mark Stream Frames

- (void)sendOpenFrame
{
    PXDocument *openFrameDocument = [[PXDocument alloc] initWithElementName:@"open"
                                                                  namespace:XMPPWebsocketStream_NS
                                                                     prefix:nil];
    [openFrameDocument.root setValue:self.hostname forAttribute:@"to"];
    [openFrameDocument.root setValue:@"1.0" forAttribute:@"version"];

    NSString *message = [[self class] stringFromDocument:openFrameDocument];
    [_websocket send:message];
}

- (void)sendCloseFrame
{
    PXDocument *closeFrameDocument = [[PXDocument alloc] initWithElementName:@"close"
                                                                   namespace:XMPPWebsocketStream_NS
                                                                      prefix:nil];
    NSString *message = [[self class] stringFromDocument:closeFrameDocument];
    [_websocket send:message];
}

#pragma mark Handle Received Documents

- (void)handleReceivedDocument:(PXDocument *)document
{
    if ([[document.root namespace] isEqualToString:XMPPWebsocketStream_NS]) {
        [self handleReceivedFramingDocument:document];
    } else {
        if (_state != XMPPStreamStateOpen) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Can only handle elements other than framing elements if the stream is open.", nil) };
            NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                                 code:XMPPStreamErrorCodeInvalidState
                                             userInfo:userInfo];
            [self handleFailureWithError:error];
        } else {

            id<XMPPStreamDelegate> delegate = self.delegate;
            dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
            dispatch_async(delegateQueue, ^{
                if ([delegate respondsToSelector:@selector(stream:didReceiveElement:)]) {
                    [self.delegate stream:self didReceiveElement:document.root];
                }
            });
        }
    }
}

- (void)handleReceivedFramingDocument:(PXDocument *)document
{
    if ([[document.root name] isEqualToString:@"open"]) {

        if (_state != XMPPStreamStateOpening) {

            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Received unexpected open frame.", nil) };
            NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                                 code:XMPPStreamErrorCodeInvalidState
                                             userInfo:userInfo];
            [self handleFailureWithError:error];

        } else {

            NSString *hostname = [document.root valueForAttribute:@"from"];
            NSString *streamId = [document.root valueForAttribute:@"id"];

            id<XMPPStreamDelegate> delegate = self.delegate;
            dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
            dispatch_async(delegateQueue, ^{
                if ([delegate respondsToSelector:@selector(stream:didOpenToHost:withStreamId:)]) {
                    [self.delegate stream:self didOpenToHost:hostname withStreamId:streamId];
                }
            });

            self.state = XMPPStreamStateOpen;
        }

    } else if ([[document.root name] isEqualToString:@"close"]) {

        if (_state != XMPPStreamStateOpen && _state != XMPPStreamStateClosing) {

            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Received unexpected close frame.", nil) };
            NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                                 code:XMPPStreamErrorCodeInvalidState
                                             userInfo:userInfo];
            [self handleFailureWithError:error];

        } else {

            if (_state == XMPPStreamStateOpen) {
                [self sendCloseFrame];
            }

            self.state = XMPPStreamStateDisconnecting;
            [_websocket close];
        }

    } else {

        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Recevied unsupported framing document.", nil) };
        NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                             code:XMPPStreamErrorCodeInvalidState
                                         userInfo:userInfo];
        [self handleFailureWithError:error];
    }
}

#pragma mark Handle Failure

- (void)handleFailureWithError:(NSError *)error
{
    id<XMPPStreamDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(delegateQueue, ^{
        if ([delegate respondsToSelector:@selector(stream:didFailWithError:)]) {
            [self.delegate stream:self didFailWithError:error];
        }
    });

    [self tearDownWebsocket];
}

#pragma Manage Websocket

- (NSURL *)websocketURL
{
    NSURL *websocketURL = self.options[XMPPWebsocketStreamURLKey];
    if (websocketURL == nil) {
        // Try to guess the websocket URL
        NSURLComponents *websocketURLComponents = [[NSURLComponents alloc] init];
        websocketURLComponents.scheme = @"ws";
        websocketURLComponents.host = self.hostname;
        websocketURLComponents.path = @"/xmpp";
        websocketURL = [websocketURLComponents URL];
    }
    return websocketURL;
}

- (void)setUpWebsocket
{
    _websocket.delegate = nil;
    [_websocket close];

    // Create a websocket with the URL form the options (or create a
    // default RUL based on the hostname) and open the websocket.

    NSURL *websocketURL = [self websocketURL];
    SRWebSocket *websocket = [[SRWebSocket alloc] initWithURL:websocketURL
                                                    protocols:@[ @"xmpp" ]
                               allowsUntrustedSSLCertificates:YES];

    [websocket setDelegateDispatchQueue:_operationQueue];
    websocket.delegate = self;

    _websocket = websocket;
}

- (void)tearDownWebsocket
{
    [_websocket close];
    _websocket.delegate = nil;
    _websocket = nil;
}

#pragma mark - SRWebSocketDelegate (called on operation queue)

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    if (_state != XMPPStreamStateConnecting) {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Expecting stream to be in state 'connection' while the connection is established.", nil) };
        NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                             code:XMPPStreamErrorCodeInvalidState
                                         userInfo:userInfo];
        [self handleFailureWithError:error];
    } else {
        self.state = XMPPStreamStateOpening;
        [self sendOpenFrame];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(NSString *)message
{
    if ([message isKindOfClass:[NSString class]]) {
#ifdef DEBUG
        NSLog(@"%@ IN  <<< %@", self, message);
#endif
        PXDocument *document = [PXDocument documentWithData:[message dataUsingEncoding:NSUTF8StringEncoding]];
        if (document) {
            [self handleReceivedDocument:document];
        } else {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Failed to parse received XML document.", nil) };
            NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                                 code:XMPPStreamErrorCodeParseError
                                             userInfo:userInfo];
            [self handleFailureWithError:error];
        }
    } else {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey :
                                        [NSString stringWithFormat:NSLocalizedString(@"Received websocket message of wrong format. Expected UTF8 encoded string. Got `%@`", nil),
                                                                   NSStringFromClass([message class])] };
        NSError *error = [NSError errorWithDomain:XMPPStreamErrorDomain
                                             code:XMPPStreamErrorCodeMessageFormatError
                                         userInfo:userInfo];
        [self handleFailureWithError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (_state == XMPPStreamStateDisconnecting) {

        id<XMPPStreamDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(streamDidClose:)]) {
                [self.delegate streamDidClose:self];
            }
        });

        [self tearDownWebsocket];
        self.state = XMPPStreamStateClosed;
    } else {
        [self handleFailureWithError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    id<XMPPStreamDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(delegateQueue, ^{
        if ([delegate respondsToSelector:@selector(streamDidClose:)]) {
            [self.delegate streamDidClose:self];
        }
    });

    [self tearDownWebsocket];
    self.state = XMPPStreamStateClosed;
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

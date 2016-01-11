//
//  XMPPClient.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPWebsocketStream.h"
#import "XMPPStreamFeature.h"
#import "XMPPStreamFeatureSASL.h"

#import "SASLMechanismPLAIN.h"

#import "XMPPClient.h"

NSString *const XMPPClientOptionsStreamKey = @"XMPPClientOptionsStreamKey";

@interface XMPPClient () <XMPPStreamDelegate, XMPPStreamFeatureDelegate, XMPPStreamFeatureDelegateSASL> {
    dispatch_queue_t _operationQueue;
    XMPPClientState _state;
    XMPPWebsocketStream *_stream;
    XMPPStreamFeature *_currentFeature;
}

@end

@implementation XMPPClient

#pragma mark Registered Stream Features

+ (NSMutableDictionary *)xmpp_registeredStreamFeatures
{
    static NSMutableDictionary *registeredStreamFeatures;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registeredStreamFeatures = [[NSMutableDictionary alloc] init];
    });
    return registeredStreamFeatures;
}

+ (NSDictionary *)registeredStreamFeatures
{
    return [self xmpp_registeredStreamFeatures];
}

+ (void)registerStreamFeatureClass:(Class)featureClass forStreamFeatureQName:(PXQName *)streamFeatureQName
{
    NSParameterAssert(featureClass);
    NSParameterAssert(streamFeatureQName);

    NSMutableDictionary *registeredStreamFeatures = [self xmpp_registeredStreamFeatures];
    [registeredStreamFeatures setObject:featureClass forKey:streamFeatureQName];
}

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
        _negotiatedFeatures = @[];
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

- (void)xmpp_beginNegotiationWithElement:(PXElement *)element
{
    _state = XMPPClientStateNegotiating;

    NSMutableArray *mandatoryFeatures = [[NSMutableArray alloc] init];
    NSMutableArray *voluntaryFeatures = [[NSMutableArray alloc] init];

    [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {

        PXQName *featureQName = [[PXQName alloc] initWithName:element.name namespace:element.namespace];

        Class featureClass = [[[self class] registeredStreamFeatures] objectForKey:featureQName];
        if (featureClass) {

            XMPPStreamFeature *feature = (XMPPStreamFeature *)[[featureClass alloc] initWithElement:element];

            if (feature.mandatory) {
                [mandatoryFeatures addObject:feature];
            } else {
                [voluntaryFeatures addObject:feature];
            }
        }

    }];

    if ([mandatoryFeatures count] > 0) {

        // Mandatory features are left for negotiation

        _currentFeature = [mandatoryFeatures firstObject];

        _currentFeature.delegate = self;
        _currentFeature.delegateQueue = _operationQueue;

        [_currentFeature beginNegotiation];

    } else if ([voluntaryFeatures count] > 0) {

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

            [self xmpp_beginNegotiationWithElement:element];

        } else {
            // Unexpected element
            _state = XMPPClientStateDisconnecting;
            [_stream close];
        }

    } else if (_state == XMPPClientStateNegotiating) {

        [_currentFeature handleElement:element];

    } else if (_state == XMPPClientStateEstablished) {

        if ([element.namespace isEqual:@"jabber:client"]) {

            if ([element.name isEqual:@"message"] ||
                [element.name isEqual:@"presence"] ||
                [element.name isEqual:@"iq"]) {

                id<XMPPClientDelegate> delegate = self.delegate;
                dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
                dispatch_async(delegateQueue, ^{
                    if ([delegate respondsToSelector:@selector(client:didReceiveStanza:)]) {
                        [delegate client:self didReceiveStanza:element];
                    }
                });

            } else {
                // Unsupported type
            }
        } else {
            // Unsupported type
        }

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

#pragma mark XMPPStreamFeatureDelegate

- (void)streamFeatureDidSucceedNegotiation:(XMPPStreamFeature *)streamFeature
{
    if (streamFeature == _currentFeature) {

        PXQName *featureQName = [[PXQName alloc] initWithName:[[streamFeature class] name]
                                                    namespace:[[streamFeature class] namespace]];

        _negotiatedFeatures = [_negotiatedFeatures arrayByAddingObject:featureQName];

        _currentFeature.delegate = nil;
        _currentFeature = nil;

        if (streamFeature.needsRestart) {
            _state = XMPPClientStateConnecting;
            [_stream reopen];
        } else {
            _state = XMPPClientStateConnected;
        }

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didNegotiateFeature:)]) {
                [delegate client:self didNegotiateFeature:featureQName];
            }
        });
    }
}

- (void)streamFeature:(XMPPStreamFeature *)streamFeature didFailNegotiationWithError:(NSError *)error
{
    if (streamFeature == _currentFeature) {

        _currentFeature.delegate = nil;
        _currentFeature = nil;

        PXQName *featureQName = [[PXQName alloc] initWithName:[[streamFeature class] name]
                                                    namespace:[[streamFeature class] namespace]];

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didFailToNegotiateFeature:withError:)]) {
                [delegate client:self didFailToNegotiateFeature:featureQName withError:error];
            }
        });

        _state = XMPPClientStateDisconnecting;
        [_stream close];
    }
}

- (void)streamFeature:(XMPPStreamFeature *)streamFeature handleElement:(PXElement *)element
{
    if (streamFeature == _currentFeature) {
        [_stream sendElement:element];
    }
}

#pragma mark XMPPStreamFeatureDelegateSASL

- (SASLMechanism *)SASLMechanismForStreamFeature:(XMPPStreamFeature *)streamFeature
                             supportedMechanisms:(NSArray *)mechanisms
{
    SASLMechanism *mechanism = [[SASLMechanismPLAIN alloc] init];
    mechanism.delegate = self.SASLDelegate;
    return mechanism;
}

@end

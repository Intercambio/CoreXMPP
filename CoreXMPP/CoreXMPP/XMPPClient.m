//
//  XMPPClient.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarn;
#endif

#import "XMPPWebsocketStream.h"
#import "XMPPStreamFeature.h"
#import "XMPPStreamFeatureSASL.h"
#import "XMPPStreamFeatureBind.h"

#import "SASLMechanism.h"

#import "XMPPClient.h"

NSString *const XMPPClientStreamErrorDomain = @"XMPPClientStreamErrorDomain";
NSString *const XMPPClientStreamErrorXMLDocumentKey = @"XMPPClientStreamErrorXMLDocument";
NSString *const XMPPClientOptionsStreamKey = @"XMPPClientOptionsStreamKey";
NSString *const XMPPClientOptionsPreferedSASLMechanismsKey = @"XMPPClientOptionsPreferedSASLMechanismsKey";
NSString *const XMPPClientOptionsResourceKey = @"XMPPClientOptionsResourceKey";

@interface XMPPClient () <XMPPStreamDelegate, XMPPStreamFeatureDelegate, XMPPStreamFeatureDelegateSASL, XMPPStreamFeatureDelegateBind> {
    dispatch_queue_t _operationQueue;
    XMPPClientState _state;
    XMPPWebsocketStream *_stream;
    XMPPStreamFeature *_currentFeature;
    NSMutableArray *_featureConfigurations;
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

#pragma mark Stream Errors

+ (NSError *)streamErrorFromElement:(PXElement *)element
{
    if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
        [element.name isEqualToString:@"error"]) {

        NSMutableArray *children = [[NSMutableArray alloc] init];
        [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
            [children addObject:element];
        }];

        NSString *errorDomain = XMPPClientStreamErrorDomain;
        __block NSInteger errorCode = XMPPClientStreamErrorCodeUndefinedCondition;
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

        PXDocument *errorDocument = [[PXDocument alloc] initWithElement:element];
        [userInfo setObject:errorDocument forKey:XMPPClientStreamErrorXMLDocumentKey];

        PXElement *errorElement = [children firstObject];
        if ([errorElement.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-streams"]) {

            NSDictionary *errorCodes = @{ @"bad-format" : @(XMPPClientStreamErrorCodeBadFormat),
                                          @"bad-namespace-prefix" : @(XMPPClientStreamErrorCodeBadNamespacePrefix),
                                          @"conflict" : @(XMPPClientStreamErrorCodeConflict),
                                          @"connection-timeout" : @(XMPPClientStreamErrorCodeConnectionTimeout),
                                          @"host-gone" : @(XMPPClientStreamErrorCodeHostGone),
                                          @"host-unknown" : @(XMPPClientStreamErrorCodeHostUnknown),
                                          @"improper-addressing" : @(XMPPClientStreamErrorCodeImproperAddressing),
                                          @"internal-server-error" : @(XMPPClientStreamErrorCodeInternalServerError),
                                          @"invalid-from" : @(XMPPClientStreamErrorCodeInvalidFrom),
                                          @"invalid-namespace" : @(XMPPClientStreamErrorCodeInvalidNamespace),
                                          @"invalid-xml" : @(XMPPClientStreamErrorCodeInvalidXML),
                                          @"not-authorized" : @(XMPPClientStreamErrorCodeNotAuthorized),
                                          @"not-well-formed" : @(XMPPClientStreamErrorCodeNotWellFormed),
                                          @"policy-violation" : @(XMPPClientStreamErrorCodePolicyViolation),
                                          @"remote-connection-failed" : @(XMPPClientStreamErrorCodeRemoteConnectionFailed),
                                          @"reset" : @(XMPPClientStreamErrorCodeReset),
                                          @"resource-constraint" : @(XMPPClientStreamErrorCodeResourceConstraint),
                                          @"restricted-xml" : @(XMPPClientStreamErrorCodeRestrictedXML),
                                          @"see-other-host" : @(XMPPClientStreamErrorCodeSeeOtherHost),
                                          @"system-shutdown" : @(XMPPClientStreamErrorCodeSystemShutdown),
                                          @"undefined-condition" : @(XMPPClientStreamErrorCodeUndefinedCondition),
                                          @"unsupported-encoding" : @(XMPPClientStreamErrorCodeUnsupportedEncoding),
                                          @"unsupported-feature" : @(XMPPClientStreamErrorCodeUnsupportedFeature),
                                          @"unsupported-stanza-type" : @(XMPPClientStreamErrorCodeUnsupportedStanzaType),
                                          @"unsupported-version" : @(XMPPClientStreamErrorCodeUnsupportedVersion) };

            errorCode = [errorCodes[errorElement.name] integerValue] ?: XMPPClientStreamErrorCodeUndefinedCondition;
        }

        if ([children count] >= 2) {
            PXElement *errorText = [children objectAtIndex:1];
            if ([errorText.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-streams"] &&
                [errorText.name isEqualToString:@"text"]) {
                [userInfo setObject:errorText.stringValue forKey:NSLocalizedDescriptionKey];
            }
        }

        return [NSError errorWithDomain:errorDomain
                                   code:errorCode
                               userInfo:userInfo];
    }

    return nil;
}

#pragma mark Life-cycle

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _options = options;
        _state = XMPPClientStateDisconnected;
        _operationQueue = dispatch_queue_create("XMPPClient", DISPATCH_QUEUE_SERIAL);
        _stream = options[XMPPClientOptionsStreamKey] ?: [[XMPPWebsocketStream alloc] initWithHostname:hostname options:options];
        _stream.delegateQueue = _operationQueue;
        _stream.delegate = self;
    }
    return self;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<XMPPClient: %p (%@)>", self, self.hostname];
}

#pragma mark Properties

- (NSString *)hostname
{
    return _stream.hostname;
}

#pragma mark Manage Client

- (void)connect
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPClientStateDisconnected, @"Invalid State: Can only connect a disconnected client.");
        _state = XMPPClientStateConnecting;
        _negotiatedFeatures = @[];

        DDLogDebug(@"Supported Features: %@", [[self class] registeredStreamFeatures]);

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
        NSAssert(_state == XMPPClientStateEstablished, @"Invalid State: Can only send stanza with a client with an established connection.");
        [_stream sendElement:stanza];
    });
}

#pragma mark Feature Negotiation

- (void)xmpp_updateSupportedFeaturesWithElement:(PXElement *)features
{
    NSMutableArray *featureConfigurations = [[NSMutableArray alloc] init];
    [features enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
        PXDocument *configuration = [[PXDocument alloc] initWithElement:element];
        [featureConfigurations addObject:configuration];
    }];
    _featureConfigurations = featureConfigurations;
}

- (void)xmpp_negotiateNextFeature
{
    _state = XMPPClientStateNegotiating;

    PXDocument *configuration = [_featureConfigurations firstObject];
    if (configuration) {
        [_featureConfigurations removeObjectAtIndex:0];

        Class featureClass = [[[self class] registeredStreamFeatures] objectForKey:configuration.root.qualifiedName];
        if (featureClass) {
            XMPPStreamFeature *feature = (XMPPStreamFeature *)[[featureClass alloc] initWithConfiguration:configuration];

            // Begin the negotiation of the feature

            _currentFeature = feature;
            _currentFeature.queue = _operationQueue;
            _currentFeature.delegate = self;

            DDLogDebug(@"Client '%@' begin negotiation of feature: (%@, %@)", self, configuration.root.namespace, configuration.root.name);

            [_currentFeature beginNegotiationWithHostname:self.hostname
                                                  options:nil];

        } else {

            DDLogDebug(@"Client '%@' does not support feature: (%@, %@)", self, configuration.root.namespace, configuration.root.name);

            [self xmpp_negotiateNextFeature];
        }

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
    id<XMPPClientDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();

    if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
        [element.name isEqualToString:@"error"]) {

        // Handle Stream Errors

        NSError *error = [[self class] streamErrorFromElement:element];

        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
                [delegate client:self didFailWithError:error];
            }
        });

        _state = XMPPClientStateDisconnecting;
        [_stream close];

    } else {

        switch (_state) {
        case XMPPClientStateConnected:
            // Expecting a features element to start the negotiation
            if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
                [element.name isEqualToString:@"features"]) {
                [self xmpp_updateSupportedFeaturesWithElement:element];
                [self xmpp_negotiateNextFeature];
            } else {
                // Unexpected element
                _state = XMPPClientStateDisconnecting;
                [_stream close];
            }
            break;

        case XMPPClientStateNegotiating:
            [_currentFeature handleElement:element];
            break;

        case XMPPClientStateEstablished: {

            if ([element.namespace isEqual:@"jabber:client"] && ([element.name isEqual:@"message"] ||
                                                                 [element.name isEqual:@"presence"] ||
                                                                 [element.name isEqual:@"iq"])) {

                dispatch_async(delegateQueue, ^{
                    if ([delegate respondsToSelector:@selector(client:didReceiveStanza:)]) {
                        [delegate client:self didReceiveStanza:element];
                    }
                });

            } else {

                // Unsupported element

                dispatch_async(delegateQueue, ^{
                    if ([delegate respondsToSelector:@selector(client:didReceiveUnsupportedElement:)]) {
                        [delegate client:self didReceiveUnsupportedElement:element];
                    }
                });
            }
            break;
        }

        case XMPPClientStateConnecting:
        case XMPPClientStateDisconnected:
        case XMPPClientStateDisconnecting:
            break;
        }
    }
}

- (void)stream:(XMPPStream *)stream didFailWithError:(NSError *)error
{
    _state = XMPPClientStateDisconnected;

    id<XMPPClientDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();

    dispatch_async(delegateQueue, ^{
        if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
            [delegate client:self didFailWithError:error];
        }
    });
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

        _negotiatedFeatures = [_negotiatedFeatures arrayByAddingObject:streamFeature];

        _currentFeature.delegate = nil;
        _currentFeature = nil;

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didNegotiateFeature:)]) {
                [delegate client:self didNegotiateFeature:streamFeature];
            }
        });

        if (streamFeature.needsRestart) {
            _state = XMPPClientStateConnecting;
            [_stream reopen];
        } else {
            [self xmpp_negotiateNextFeature];
        }
    }
}

- (void)streamFeature:(XMPPStreamFeature *)streamFeature didFailNegotiationWithError:(NSError *)error
{
    if (streamFeature == _currentFeature) {

        _currentFeature.delegate = nil;
        _currentFeature = nil;

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didFailToNegotiateFeature:withError:)]) {
                [delegate client:self didFailToNegotiateFeature:streamFeature withError:error];
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
    NSArray *preferredMechanisms = [self.options objectForKey:XMPPClientOptionsPreferedSASLMechanismsKey] ?: mechanisms;

    SASLMechanism *mechanism = nil;

    NSDictionary *registeredMechanisms = [SASLMechanism registeredMechanisms];

    for (NSString *mechanismName in preferredMechanisms) {
        if ([mechanisms containsObject:mechanismName]) {
            Class mechanismClass = [registeredMechanisms objectForKey:mechanismName];
            if (mechanismClass) {
                mechanism = [[mechanismClass alloc] init];
                break;
            }
        }
    }

    mechanism.delegate = self.SASLDelegate;
    mechanism.delegateQueue = self.SASLDelegateQueue;
    mechanism.context = self.SASLContext;
    return mechanism;
}

#pragma mark XMPPStreamFeatureDelegateBind

- (NSString *)resourceNameForStreamFeature:(XMPPStreamFeature *)streamFeature
{
    return self.options[XMPPClientOptionsResourceKey];
}

@end
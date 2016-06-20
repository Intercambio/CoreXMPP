//
//  XMPPClient.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <SASLKit/SASLKit.h>

#import "XMPPError.h"
#import "XMPPStreamFeature.h"
#import "XMPPStreamFeatureBind.h"
#import "XMPPStreamFeatureSASL.h"
#import "XMPPStreamFeatureStreamManagement.h"
#import "XMPPStreamStanzaHandlerProxy.h"
#import "XMPPWebsocketStream.h"

#import "XMPPClient.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPClientOptionsPreferedSASLMechanismsKey = @"XMPPClientOptionsPreferedSASLMechanismsKey";
NSString *const XMPPClientOptionsResourceKey = @"XMPPClientOptionsResourceKey";

NSString *const XMPPClientDidConnectNotification = @"XMPPClientDidConnectNotification";
NSString *const XMPPClientDidDisconnectNotification = @"XMPPClientDidDisconnectNotification";
NSString *const XMPPClientErrorKey = @"XMPPClientErrorKey";
NSString *const XMPPClientResumedKey = @"XMPPClientResumedKey";

@interface XMPPClient () <XMPPStreamDelegate, XMPPStreamFeatureDelegate, XMPPStreamFeatureDelegateSASL, XMPPStreamFeatureDelegateBind> {
    dispatch_queue_t _operationQueue;
    XMPPClientState _state;
    XMPPStream *_stream;
    XMPPStreamFeature *_currentFeature;
    NSMutableDictionary *_featureConfigurations;
    NSMutableArray *_preferredFeatures;
    NSArray *_negotiatedFeatures;
    id<XMPPStanzaHandler> _streamFeatureStanzaHandler;
    XMPPStreamFeature<XMPPClientStreamManagement> *_streamManagement;
    XMPPJID *_JID;
}

@end

@implementation XMPPClient

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

@synthesize connectionDelegate = _connectionDelegate;

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    return [self initWithHostname:hostname
                          options:options
                           stream:nil];
}

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
                          stream:(XMPPStream *)stream
{
    self = [super init];
    if (self) {
        _hostname = hostname;
        _options = options;
        _state = XMPPClientStateDisconnected;
        _operationQueue = dispatch_queue_create("XMPPClient", DISPATCH_QUEUE_SERIAL);
        _stream = stream ?: [[XMPPWebsocketStream alloc] initWithHostname:hostname options:options];
        _stream.queue = _operationQueue;
        _stream.delegate = self;
        _streamFeatureStanzaHandler = [[XMPPStreamStanzaHandlerProxy alloc] initWithStream:_stream];
    }
    return self;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<XMPPClient: %p (%@) state: %ld>", self, self.hostname, (unsigned long)self.state];
}

#pragma mark Options

- (void)updateOptions:(NSDictionary *)options
{
    dispatch_async(_operationQueue, ^{
        _options = options;
    });
}

#pragma mark State

- (void)setState:(XMPPClientState)state
{
    if (_state != state) {
        _state = state;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([self.delegate respondsToSelector:@selector(client:didChangeState:)]) {
                [self.delegate client:self didChangeState:state];
            }
        });
    }
}

#pragma mark Manage Client

- (void)connect
{
    dispatch_async(_operationQueue, ^{
        if (self.state != XMPPClientStateDisconnected) {
            DDLogWarn(@"Invalid State: Can only connect a disconnected client: %@", self);
        } else {
            DDLogInfo(@"Connecting: '%@'.", self.hostname);

            self.state = XMPPClientStateConnecting;
            _negotiatedFeatures = @[];
            _currentFeature = nil;
            _featureConfigurations = nil;
            _stream.options = self.options;
            [_stream open];
        }
    });
}

- (void)disconnect
{
    dispatch_async(_operationQueue, ^{

        if (self.state != XMPPClientStateConnected) {
            DDLogWarn(@"Invalid State: Can only disconnect a connected client: %@", self);
        } else {
            DDLogInfo(@"Disconnecting: '%@'.", self.hostname);

            self.state = XMPPClientStateDisconnecting;

            [_streamManagement sendAcknowledgement];
            [_streamManagement cancelUnacknowledgedStanzas];
            [_stream close];
            _streamManagement = nil;
            _negotiatedFeatures = @[];
        }
    });
}

- (void)suspend
{
    dispatch_async(_operationQueue, ^{
        if (self.state != XMPPClientStateConnected) {
            DDLogWarn(@"Invalid State: Can only suspend a connected client: %@", self);
        } else {
            DDLogInfo(@"Suspending: %@", self);

            self.state = XMPPClientStateDisconnecting;

            [_streamManagement sendAcknowledgement];
            [_stream suspend];
            if (_streamManagement.resumable == NO) {
                _streamManagement = nil;
            }
        }
    });
}

#pragma mark Acknowledgement

- (void)exchangeAcknowledgement
{
    dispatch_async(_operationQueue, ^{
        if (self.state != XMPPClientStateConnected) {
            DDLogWarn(@"Invalid State: Could not exchange acknowledgement, because the client is not connected: %@", self);
        } else {
            [_streamManagement sendAcknowledgement];
            [_streamManagement requestAcknowledgement];
        }
    });
}

#pragma mark -
#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{

        if (self.state == XMPPClientStateConnected ||
            _streamManagement.enabled) {

            // The stanza can be handled if the connection to the server is established
            // or if the client supports stream management (and can resend the stanza later).

            if (self.state == XMPPClientStateConnected) {
                [_stream sendElement:stanza];
            } else {
                DDLogDebug(@"Stanza can not be sended by client directly, because there is no stream to the host. Will be send later if the connection has been resumed.");
            }

            if (_streamManagement.enabled) {
                [_streamManagement didSentStanza:stanza acknowledgement:completion];
            } else if (completion) {
                completion(nil);
            }

        } else {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeNotConnected
                                             userInfo:nil];
            if (completion) {
                completion(error);
            }
        }
    });
}

- (void)processPendingStanzas:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        if (completion) {
            completion(nil);
        }
    });
}

#pragma mark -
#pragma mark Feature Negotiation

- (void)xmpp_updatePreferredFeatures
{
    _preferredFeatures = [[NSMutableArray alloc] init];

    if (_streamManagement.resumable) {
        [_preferredFeatures addObject:PXQN(@"urn:ietf:params:xml:ns:xmpp-sasl", @"mechanisms")];
        [_preferredFeatures addObject:PXQN(@"urn:xmpp:sm:3", @"sm")];
    } else {
        [_preferredFeatures addObject:PXQN(@"urn:ietf:params:xml:ns:xmpp-sasl", @"mechanisms")];
        [_preferredFeatures addObject:PXQN(@"urn:ietf:params:xml:ns:xmpp-bind", @"bind")];
        [_preferredFeatures addObject:PXQN(@"urn:ietf:params:xml:ns:xmpp-session", @"session")];
        [_featureConfigurations enumerateKeysAndObjectsUsingBlock:^(PXQName *name, PXDocument *configuration, BOOL *stop) {
            if (![name isEqual:PXQN(@"urn:xmpp:sm:3", @"sm")] &&
                ![_preferredFeatures containsObject:name]) {
                [_preferredFeatures addObject:name];
            }
        }];
        [_preferredFeatures addObject:PXQN(@"urn:xmpp:sm:3", @"sm")];
    }
}

- (void)xmpp_updateSupportedFeaturesWithElement:(PXElement *)features
{
    DDLogInfo(@"Client '%@' updating features: %@", self, features.document);

    NSMutableDictionary *featureConfigurations = [[NSMutableDictionary alloc] init];

    [features enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
        PXDocument *configuration = [[PXDocument alloc] initWithElement:element];
        [featureConfigurations setObject:configuration forKey:configuration.root.qualifiedName];
    }];

    _featureConfigurations = featureConfigurations;
    [self xmpp_updatePreferredFeatures];
}

- (XMPPStreamFeature *)xmpp_featureWithQName:(PXQName *)QName
{
    for (XMPPStreamFeature *feature in _negotiatedFeatures) {
        if ([[[feature class] name] isEqualToString:QName.name] &&
            [[[feature class] namespace] isEqualToString:QName.namespace]) {
            return feature;
        }
    }
    return nil;
}

- (PXDocument *)xmpp_nextFeatureConfiguration
{
    if ([_preferredFeatures count] > 0) {

        PXQName *featureName = [_preferredFeatures firstObject];
        PXDocument *configuration = _featureConfigurations[featureName];

        [_preferredFeatures removeObject:featureName];

        if (configuration) {
            return configuration;
        } else {
            return [self xmpp_nextFeatureConfiguration];
        }
    } else {
        return nil;
    }
}

- (void)xmpp_negotiateNextFeature
{
    self.state = XMPPClientStateNegotiating;

    PXDocument *configuration = [self xmpp_nextFeatureConfiguration];
    if (configuration) {

        XMPPStreamFeature *feature = nil;

        if (_streamManagement.resumable && [configuration.root.qualifiedName isEqual:PXQN(@"urn:xmpp:sm:3", @"sm")]) {
            // Reuse previous stream management feature
            feature = _streamManagement;
        } else {
            feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
        }

        if (feature) {

            if ([feature.configuration.root.qualifiedName isEqual:PXQN(@"urn:ietf:params:xml:ns:xmpp-bind", @"bind")]) {
                // Reset client JID if we have to bind the client (and not resuming a session).
                _JID = nil;
            }

            // Begin the negotiation of the feature

            _currentFeature = feature;
            _currentFeature.queue = _operationQueue;
            _currentFeature.delegate = self;
            _currentFeature.stanzaHandler = _streamFeatureStanzaHandler;

            DDLogInfo(@"Client '%@' begin negotiation of feature: (%@, %@)", self, configuration.root.namespace, configuration.root.name);

            [_currentFeature beginNegotiationWithHostname:self.hostname
                                                  options:nil];

        } else {

            DDLogInfo(@"Client '%@' does not support feature: (%@, %@)", self, configuration.root.namespace, configuration.root.name);

            [self xmpp_negotiateNextFeature];
        }

    } else {

        // No features left to negotiate
        // The connection is established

        self.state = XMPPClientStateConnected;

        _numberOfConnectionAttempts = 0;
        _recentError = nil;

        BOOL resumed = _streamManagement.resumed;

        [_connectionDelegate connection:self didConnectTo:_JID resumed:resumed];

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{

            if ([delegate respondsToSelector:@selector(clientDidConnect:resumedStream:)]) {
                [delegate clientDidConnect:self resumedStream:resumed];
            }

            NSDictionary *userInfo = @{ XMPPClientResumedKey : @(resumed) };
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidConnectNotification
                                                                object:self
                                                              userInfo:userInfo];
        });
    }
}

- (XMPPStreamFeature *)xmpp_negotiatedFeaturesWithQName:(PXQName *)QName
{
    for (XMPPStreamFeature *feature in _negotiatedFeatures) {
        if ([[[feature class] name] isEqualToString:QName.name] &&
            [[[feature class] namespace] isEqualToString:QName.namespace]) {
            return feature;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark XMPPStreamDelegate (called on operation queue)

- (void)stream:(XMPPStream *)stream didOpenToHost:(NSString *)hostname withStreamId:(NSString *)streamId
{
    self.state = XMPPClientStateEstablished;
}

- (void)stream:(XMPPStream *)stream didReceiveElement:(PXElement *)element
{
    id<XMPPClientDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();

    if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
        [element.name isEqualToString:@"error"]) {

        // Handle Stream Errors

        self.state = XMPPClientStateDisconnected;

        NSError *error = [NSError streamErrorFromElement:element];
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
                [delegate client:self didFailWithError:error];
            }

            NSDictionary *userInfo = error ? @{XMPPClientErrorKey : error} : @{};
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                                object:self
                                                              userInfo:userInfo];
        });

        [_stream close];

    } else {

        switch (self.state) {
        case XMPPClientStateEstablished:
            // Expecting a features element to start the negotiation
            if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
                [element.name isEqualToString:@"features"]) {
                [self xmpp_updateSupportedFeaturesWithElement:element];
                [self xmpp_negotiateNextFeature];
            } else {
                // Unexpected element
                self.state = XMPPClientStateDisconnecting;
                [_stream close];
            }
            break;

        case XMPPClientStateNegotiating: {
            [_currentFeature handleStanza:element
                               completion:^(NSError *error) {
                                   if (error) {
                                       DDLogError(@"Stream feature %@ failed to handle element with error: %@",
                                                  _currentFeature,
                                                  [error localizedDescription]);
                                   }
                               }];
            break;
        }

        case XMPPClientStateConnected: {

            if ([element.namespace isEqual:@"jabber:client"] && ([element.name isEqual:@"message"] ||
                                                                 [element.name isEqual:@"presence"] ||
                                                                 [element.name isEqual:@"iq"])) {
                [_connectionDelegate handleStanza:element
                                       completion:^(NSError *error) {
                                           dispatch_async(_operationQueue, ^{
                                               if (error) {
                                                   DDLogError(@"Failed to handle stanza with error: %@", [error localizedDescription]);
                                               } else {
                                                   [_streamManagement didHandleReceviedStanza:element];
                                               }
                                           });
                                       }];
            } else {
                [_connectionDelegate processPendingStanzas:^(NSError *error) {
                    dispatch_async(_operationQueue, ^{
                        if (error) {
                            DDLogError(@"Failed to process pending stanzas with error: %@", [error localizedDescription]);
                        } else {
                            BOOL handled = NO;
                            for (XMPPStreamFeature *feature in _negotiatedFeatures) {
                                if ([[[feature class] namespace] isEqualToString:element.namespace]) {
                                    [feature handleStanza:element completion:nil];
                                    handled = YES;
                                    break;
                                }
                            }
                            if (!handled) {
                                // Unsupported element
                                dispatch_async(delegateQueue, ^{
                                    if ([delegate respondsToSelector:@selector(client:didReceiveUnsupportedElement:)]) {
                                        [delegate client:self didReceiveUnsupportedElement:element];
                                    }
                                });
                            }
                        }
                    });
                }];
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
    if (self.state != XMPPClientStateDisconnected) {
        self.state = XMPPClientStateDisconnected;

        [_connectionDelegate connection:self didDisconnectFrom:_JID];

        _numberOfConnectionAttempts += 1;
        _recentError = error;

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{

            if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
                [delegate client:self didFailWithError:error];
            }

            NSDictionary *userInfo = error ? @{XMPPClientErrorKey : error} : @{};
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                                object:self
                                                              userInfo:userInfo];
        });
    }
}

- (void)streamDidClose:(XMPPStream *)stream
{
    if (self.state != XMPPClientStateDisconnected) {
        self.state = XMPPClientStateDisconnected;

        [_connectionDelegate connection:self didDisconnectFrom:_JID];

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{

            if ([delegate respondsToSelector:@selector(clientDidDisconnect:)]) {
                [delegate clientDidDisconnect:self];
            }

            NSDictionary *userInfo = @{};
            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                                object:self
                                                              userInfo:userInfo];
        });
    }
}

#pragma mark XMPPStreamFeatureDelegate  (called on operation queue)

- (void)streamFeatureDidSucceedNegotiation:(XMPPStreamFeature *)streamFeature
{
    if (streamFeature == _currentFeature) {

        DDLogInfo(@"Client '%@' succeed negotiation of feature: (%@, %@)", self, [[streamFeature class] namespace], [[streamFeature class] name]);

        _negotiatedFeatures = [_negotiatedFeatures arrayByAddingObject:streamFeature];
        _currentFeature = nil;

        if ([streamFeature conformsToProtocol:@protocol(XMPPClientStreamManagement)]) {
            _streamManagement = (XMPPStreamFeature<XMPPClientStreamManagement> *)streamFeature;
        }

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didNegotiateFeature:)]) {
                [delegate client:self didNegotiateFeature:streamFeature];
            }
        });

        if (streamFeature.needsRestart) {
            self.state = XMPPClientStateConnecting;
            DDLogInfo(@"Client '%@' resetting stream.", self);
            [_stream reopen];
        } else {
            [self xmpp_negotiateNextFeature];
        }
    }
}

- (void)streamFeature:(XMPPStreamFeature *)streamFeature didFailNegotiationWithError:(NSError *)error
{
    if (streamFeature == _currentFeature) {

        DDLogWarn(@"Client '%@' failed negotiation of feature: (%@, %@) error: %@", self, [[streamFeature class] namespace], [[streamFeature class] name], [error localizedDescription]);

        _currentFeature.delegate = nil;
        _currentFeature = nil;

        if (streamFeature.mandatory == NO) {

            if (streamFeature == _streamManagement) {
                _streamManagement = nil;
                [self xmpp_updatePreferredFeatures];
            }

            [self xmpp_negotiateNextFeature];

        } else {
            id<XMPPClientDelegate> delegate = self.delegate;
            dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
            dispatch_async(delegateQueue, ^{
                if ([delegate respondsToSelector:@selector(client:didFailToNegotiateFeature:withError:)]) {
                    [delegate client:self didFailToNegotiateFeature:streamFeature withError:error];
                }
            });

            self.state = XMPPClientStateDisconnected;

            [_connectionDelegate connection:self didDisconnectFrom:_JID];

            _numberOfConnectionAttempts += 1;
            _recentError = error;

            dispatch_async(delegateQueue, ^{

                if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
                    [delegate client:self didFailWithError:error];
                }

                NSDictionary *userInfo = error ? @{XMPPClientErrorKey : error} : @{};
                [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                                    object:self
                                                                  userInfo:userInfo];
            });

            [_stream close];
        }
    }
}

#pragma mark XMPPStreamFeatureDelegateSASL (called on operation queue)

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

#pragma mark XMPPStreamFeatureDelegateBind (called on operation queue)

- (NSString *)resourceNameForStreamFeature:(XMPPStreamFeature *)streamFeature
{
    return self.options[XMPPClientOptionsResourceKey];
}

- (void)streamFeature:(XMPPStreamFeature *)streamFeature didBindToJID:(XMPPJID *)JID
{
    _JID = JID;
}

@end

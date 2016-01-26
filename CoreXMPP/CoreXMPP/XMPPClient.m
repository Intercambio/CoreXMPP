//
//  XMPPClient.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPError.h"
#import "XMPPWebsocketStream.h"
#import "XMPPStreamFeature.h"
#import "XMPPStreamFeatureSASL.h"
#import "XMPPStreamFeatureBind.h"
#import "XMPPStreamFeatureStreamManagement.h"
#import "XMPPStreamStanzaHandlerProxy.h"

#import "SASLMechanism.h"

#import "XMPPClient.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPClientOptionsStreamKey = @"XMPPClientOptionsStreamKey";
NSString *const XMPPClientOptionsPreferedSASLMechanismsKey = @"XMPPClientOptionsPreferedSASLMechanismsKey";
NSString *const XMPPClientOptionsResourceKey = @"XMPPClientOptionsResourceKey";

@interface XMPPClient () <XMPPStreamDelegate,
                          XMPPStreamFeatureDelegate,
                          XMPPStreamFeatureDelegateSASL,
                          XMPPStreamFeatureDelegateBind> {
    dispatch_queue_t _operationQueue;
    XMPPClientState _state;
    XMPPWebsocketStream *_stream;
    XMPPStreamFeature *_currentFeature;
    NSMutableArray *_featureConfigurations;
    id<XMPPStanzaHandler> _streamFeatureStanzaHandler;
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

@synthesize stanzaHandler = _stanzaHandler;

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _hostname = hostname;
        _options = options;
        _state = XMPPClientStateDisconnected;
        _operationQueue = dispatch_queue_create("XMPPClient", DISPATCH_QUEUE_SERIAL);
        _stream = options[XMPPClientOptionsStreamKey] ?: [[XMPPWebsocketStream alloc] initWithHostname:hostname options:options];
        _stream.queue = _operationQueue;
        _stream.delegate = self;
        _streamFeatureStanzaHandler = [[XMPPStreamStanzaHandlerProxy alloc] initWithStream:_stream];
    }
    return self;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<XMPPClient: %p (%@)>", self, self.hostname];
}

#pragma mark Manage Client

- (void)connect
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPClientStateDisconnected, @"Invalid State: Can only connect a disconnected client.");

        DDLogInfo(@"Connecting: '%@'.", self.hostname);

        _state = XMPPClientStateConnecting;
        _negotiatedFeatures = @[];
        [_stream open];
    });
}

- (void)disconnect
{
    dispatch_async(_operationQueue, ^{
        NSAssert(_state == XMPPClientStateEstablished, @"Invalid State: Can only disconnect a client with an established connection.");

        DDLogInfo(@"Disconnecting: '%@'.", self.hostname);

        _state = XMPPClientStateDisconnecting;
        [_stanzaHandler processPendingStanzas:^(NSError *error) {
            dispatch_async(_operationQueue, ^{
                [_stream close];
            });
        }];
    });
}

#pragma mark -
#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    dispatch_async(_operationQueue, ^{
        NSError *error = nil;
        if (_state == XMPPClientStateEstablished) {
            [_stream sendElement:stanza];
            [_streamManagement didSentStanza:stanza];
        } else {
            error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                        code:XMPPDispatcherErrorCodeNotConnected
                                    userInfo:nil];
        }
        if (completion) {
            completion(error);
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

        XMPPStreamFeature *feature = [XMPPStreamFeature streamFeatureWithConfiguration:configuration];
        if (feature) {

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
    _state = XMPPClientStateConnected;
}

- (void)stream:(XMPPStream *)stream didReceiveElement:(PXElement *)element
{
    id<XMPPClientDelegate> delegate = self.delegate;
    dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();

    if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
        [element.name isEqualToString:@"error"]) {

        // Handle Stream Errors

        _state = XMPPClientStateDisconnected;

        NSError *error = [NSError streamErrorFromElement:element];
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
                [delegate client:self didFailWithError:error];
            }
        });

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

        case XMPPClientStateEstablished: {

            if ([element.namespace isEqual:@"jabber:client"] && ([element.name isEqual:@"message"] ||
                                                                 [element.name isEqual:@"presence"] ||
                                                                 [element.name isEqual:@"iq"])) {
                [_stanzaHandler handleStanza:element
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
                [_stanzaHandler processPendingStanzas:^(NSError *error) {
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
    if (_state != XMPPClientStateDisconnected) {
        _state = XMPPClientStateDisconnected;

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(client:didFailWithError:)]) {
                [delegate client:self didFailWithError:error];
            }
        });
    }
}

- (void)streamDidClose:(XMPPStream *)stream
{
    if (_state != XMPPClientStateDisconnected) {
        _state = XMPPClientStateDisconnected;

        id<XMPPClientDelegate> delegate = self.delegate;
        dispatch_queue_t delegateQueue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(delegateQueue, ^{
            if ([delegate respondsToSelector:@selector(clientDidDisconnect:)]) {
                [delegate clientDidDisconnect:self];
            }
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
            _streamManagement = (id<XMPPClientStreamManagement>)streamFeature;
        }

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

        DDLogWarn(@"Client '%@' failed negotiation of feature: (%@, %@) error: %@", self, [[streamFeature class] namespace], [[streamFeature class] name], [error localizedDescription]);

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

@end

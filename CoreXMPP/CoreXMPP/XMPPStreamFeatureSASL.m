//
//  XMPPStreamFeatureSASL.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPClient.h"
#import "XMPPError.h"
#import "XMPPStreamFeatureSASL.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPStreamFeatureSASLNamespace = @"urn:ietf:params:xml:ns:xmpp-sasl";

@interface XMPPStreamFeatureSASL () {
    SASLMechanism *_mechanism;
    NSString *_hostname;
}

@end

@implementation XMPPStreamFeatureSASL

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureSASL name] namespace:[XMPPStreamFeatureSASL namespace]];
    [self registerStreamFeatureClass:[XMPPStreamFeatureSASL class] forStreamFeatureQName:QName];
}

#pragma mark Logging

+ (DDLogLevel)ddLogLevel
{
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel
{
    ddLogLevel = logLevel;
}

#pragma mark SASL Errors

+ (NSError *)errorFromElement:(PXElement *)element
{
    if ([element.namespace isEqualToString:XMPPStreamFeatureSASLNamespace] &&
        [element.name isEqualToString:@"failure"]) {

        NSMutableArray *children = [[NSMutableArray alloc] init];
        [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
            [children addObject:element];
        }];

        NSString *errorDomain = XMPPStreamFeatureSASLErrorDomain;
        __block NSInteger errorCode = XMPPStreamFeatureSASLErrorCodeNotAuthorized;
        __block NSDictionary *userInfo = @{};

        PXElement *errorElement = [children firstObject];
        if ([errorElement.namespace isEqualToString:XMPPStreamFeatureSASLNamespace]) {

            NSDictionary *errorCodes = @{ @"aborted" : @(XMPPStreamFeatureSASLErrorCodeAborted),
                                          @"account-disabled" : @(XMPPStreamFeatureSASLErrorCodeAccountDisabled),
                                          @"credentials-expired" : @(XMPPStreamFeatureSASLErrorCodeCredentialsExpired),
                                          @"encryption-required" : @(XMPPStreamFeatureSASLErrorCodeEncryptionRequired),
                                          @"incorrect-encoding" : @(XMPPStreamFeatureSASLErrorCodeIncorrectEncoding),
                                          @"invalid-authzid" : @(XMPPStreamFeatureSASLErrorCodeInvalidAuthzid),
                                          @"invalid-mechanism" : @(XMPPStreamFeatureSASLErrorCodeInvalidMechanism),
                                          @"malformed-request" : @(XMPPStreamFeatureSASLErrorCodeMalformedRequest),
                                          @"mechanism-too-weak" : @(XMPPStreamFeatureSASLErrorCodeMechanismTooWeak),
                                          @"not-authorized" : @(XMPPStreamFeatureSASLErrorCodeNotAuthorized),
                                          @"temporary-auth-failure" : @(XMPPStreamFeatureSASLErrorCodeTemporaryAuthFailure) };

            // Undefined erros should be treated as "not-authorized".
            // See: RFC 6120 - 6.5. SASL Errors

            errorCode = [errorCodes[errorElement.name] integerValue] ?: XMPPStreamFeatureSASLErrorCodeNotAuthorized;
        }

        PXElement *errorText = [children lastObject];
        if ([errorText.namespace isEqualToString:XMPPStreamFeatureSASLNamespace] &&
            [errorText.name isEqualToString:@"text"]) {
            userInfo = @{NSLocalizedDescriptionKey : errorText.stringValue};
        }

        return [NSError errorWithDomain:errorDomain
                                   code:errorCode
                               userInfo:userInfo];
    }

    return nil;
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return @"mechanisms";
}

+ (NSString *)namespace
{
    return XMPPStreamFeatureSASLNamespace;
}

#pragma mark Life-cycle

- (id)initWithConfiguration:(PXDocument *)configuration
{
    self = [super initWithConfiguration:configuration];
    if (self) {

        NSMutableArray *mechanisms = [[NSMutableArray alloc] init];

        [configuration.root enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {

            if ([element.namespace isEqualToString:XMPPStreamFeatureSASLNamespace] &&
                [element.name isEqualToString:@"mechanism"]) {
                NSString *mechanism = element.stringValue;
                if (mechanism) {
                    [mechanisms addObject:mechanism];
                }
            }
        }];

        _mechanisms = mechanisms;
    }
    return self;
}

#pragma mark Feature Properties

- (BOOL)isMandatory
{
    return YES;
}

- (BOOL)needsRestart
{
    return YES;
}

#pragma mark Negotiate Feature

- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options
{
    _hostname = hostname;

    SASLMechanism *mechanism = nil;
    dispatch_queue_t queue = self.queue ?: dispatch_get_main_queue();

    if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateSASL)]) {
        id<XMPPStreamFeatureDelegateSASL> delegate = (id<XMPPStreamFeatureDelegateSASL>)self.delegate;

        // Get the SASL Mechanism
        if ([delegate respondsToSelector:@selector(SASLMechanismForStreamFeature:supportedMechanisms:)]) {
            mechanism = [delegate SASLMechanismForStreamFeature:self supportedMechanisms:self.mechanisms];
        }
        _mechanism = mechanism;
    }

    if (_mechanism) {

        DDLogInfo(@"Begin SASL authentication exchange with host '%@' using mechanism '%@'.", _hostname, [[_mechanism class] name]);

        [_mechanism beginAuthenticationExchangeWithHostname:hostname
                                            responseHandler:^(NSData *initialResponse, BOOL abort) {
                                                dispatch_async(queue, ^{

                                                    PXDocument *request = nil;

                                                    if (abort) {
                                                        if ([self.delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
                                                            NSError *error = [NSError errorWithDomain:XMPPStreamFeatureSASLErrorDomain
                                                                                                 code:XMPPStreamFeatureSASLErrorCodeAborted
                                                                                             userInfo:nil];
                                                            [self.delegate streamFeature:self didFailNegotiationWithError:error];
                                                        }
                                                    } else {
                                                        request = [[PXDocument alloc] initWithElementName:@"auth"
                                                                                                namespace:XMPPStreamFeatureSASLNamespace
                                                                                                   prefix:nil];

                                                        [request.root setValue:[[_mechanism class] name] forAttribute:@"mechanism"];

                                                        if (initialResponse) {
                                                            NSString *initialResponseString = [initialResponse base64EncodedStringWithOptions:0];
                                                            [request.root setStringValue:initialResponseString];
                                                        }

                                                        [self.stanzaHandler handleStanza:request.root
                                                                              completion:^(NSError *error){

                                                                              }];
                                                    }
                                                });
                                            }];
    } else {

        DDLogError(@"Delegate does not provide a SASL mechanism for the provided mechansims (%@).", [self.mechanisms componentsJoinedByString:@", "]);

        NSError *error = [NSError errorWithDomain:XMPPStreamFeatureSASLErrorDomain
                                             code:XMPPStreamFeatureSASLErrorCodeInvalidMechanism
                                         userInfo:nil];
        if ([self.delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
        }
    }
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *error))completion
{
    if ([stanza.namespace isEqualToString:XMPPStreamFeatureSASLNamespace]) {

        if ([stanza.name isEqualToString:@"success"]) {

            DDLogInfo(@"Did authenticated against host '%@'.", _hostname);

            NSString *responseString = stanza.stringValue;
            NSData *responseData = [responseString length] > 0 ? [[NSData alloc] initWithBase64EncodedString:responseString options:0] : nil;

            [_mechanism succeedWithData:responseData];

            [self xmpp_handleSuccess];

        } else if ([stanza.name isEqualToString:@"failure"]) {

            NSError *error = [[self class] errorFromElement:stanza];

            DDLogWarn(@"Did fail to authenticated against host '%@' with error: %@", _hostname, [error localizedDescription]);

            [_mechanism failedWithError:error];

            [self xmpp_handleFailureWithError:error];

        } else if ([stanza.name isEqualToString:@"challenge"]) {

            NSString *challengeString = stanza.stringValue;
            NSData *challengeData = [challengeString length] > 0 ? [[NSData alloc] initWithBase64EncodedString:challengeString options:0] : nil;

            dispatch_queue_t queue = self.queue ?: dispatch_get_main_queue();

            [_mechanism handleChallenge:challengeData
                        responseHandler:^(NSData *responseData, BOOL abort) {
                            dispatch_async(queue, ^{

                                PXDocument *response = nil;

                                if (abort) {
                                    response = [[PXDocument alloc] initWithElementName:@"abort"
                                                                             namespace:XMPPStreamFeatureSASLNamespace
                                                                                prefix:nil];
                                } else {
                                    response = [[PXDocument alloc] initWithElementName:@"response"
                                                                             namespace:XMPPStreamFeatureSASLNamespace
                                                                                prefix:nil];

                                    if (responseData) {
                                        NSString *responseString = [responseData base64EncodedStringWithOptions:0];
                                        [response.root setStringValue:responseString];
                                    }
                                }

                                [self.stanzaHandler handleStanza:response.root
                                                      completion:^(NSError *error){

                                                      }];
                            });
                        }];
        }
    }

    if (completion) {
        completion(nil);
    }
}

#pragma mark -

- (void)xmpp_handleSuccess
{
    if ([self.delegate respondsToSelector:@selector(streamFeatureDidSucceedNegotiation:)]) {
        [self.delegate streamFeatureDidSucceedNegotiation:self];
    }
}

- (void)xmpp_handleFailureWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
        [self.delegate streamFeature:self didFailNegotiationWithError:error];
    }
}

@end

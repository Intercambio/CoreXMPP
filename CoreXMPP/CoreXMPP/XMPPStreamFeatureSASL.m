//
//  XMPPStreamFeatureSASL.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
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

#import "XMPPClient.h"
#import "XMPPError.h"
#import "XMPPStreamFeatureSASL.h"

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

#pragma mark Mechanisms

@synthesize mechanisms = _mechanisms;
- (NSArray *)mechanisms
{
    return _mechanisms ?: @[];
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

        NSLog(@"Begin SASL authentication exchange with host '%@' using mechanism '%@'.", _hostname, [[_mechanism class] name]);

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

                                                        [self.delegate streamFeature:self handleDocument:request];
                                                    }
                                                });
                                            }];
    } else {

        NSLog(@"Delegate does not provide a SASL mechanism for the provided mechansims (%@).", [self.mechanisms componentsJoinedByString:@", "]);

        NSError *error = [NSError errorWithDomain:XMPPStreamFeatureSASLErrorDomain
                                             code:XMPPStreamFeatureSASLErrorCodeInvalidMechanism
                                         userInfo:nil];
        if ([self.delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
        }
    }
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    PXElement *stanza = document.root;

    if ([stanza.namespace isEqualToString:XMPPStreamFeatureSASLNamespace]) {

        if ([stanza.name isEqualToString:@"success"]) {

            NSLog(@"Did authenticated against host '%@'.", _hostname);

            NSString *responseString = stanza.stringValue;
            NSData *responseData = [responseString length] > 0 ? [[NSData alloc] initWithBase64EncodedString:responseString options:0] : nil;

            [_mechanism succeedWithData:responseData];

            [self xmpp_handleSuccess];

        } else if ([stanza.name isEqualToString:@"failure"]) {

            NSError *error = [[self class] errorFromElement:stanza];

            NSLog(@"Did fail to authenticated against host '%@' with error: %@", _hostname, [error localizedDescription]);

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

                                [self.delegate streamFeature:self handleDocument:response];
                            });
                        }];
        }
    }

    return YES;
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

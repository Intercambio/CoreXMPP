//
//  XMPPStreamFeatureSASL.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClient.h"

#import "XMPPStreamFeatureSASL.h"

NSString *const XMPPStreamFeatureSASLErrorDomain = @"XMPPStreamFeatureSASLErrorDomain";

NSString *const XMPPStreamFeatureSASLNamespace = @"urn:ietf:params:xml:ns:xmpp-sasl";

@interface XMPPStreamFeatureSASL () {
    SASLMechanism *_mechanism;
}

@end

@implementation XMPPStreamFeatureSASL

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureSASL name] namespace:[XMPPStreamFeatureSASL namespace]];
    [XMPPClient registerStreamFeatureClass:[XMPPStreamFeatureSASL class] forStreamFeatureQName:QName];
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

+ (NSString *) namespace
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

- (void)beginNegotiation
{
    if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateSASL)]) {
        id<XMPPStreamFeatureDelegateSASL> delegate = (id<XMPPStreamFeatureDelegateSASL>)self.delegate;

        dispatch_queue_t queue = self.queue ?: dispatch_get_main_queue();

        // Get the SASL Mechanism
        SASLMechanism *mechanism = nil;
        if ([delegate respondsToSelector:@selector(SASLMechanismForStreamFeature:supportedMechanisms:)]) {
            mechanism = [delegate SASLMechanismForStreamFeature:self supportedMechanisms:self.mechanisms];
        }
        _mechanism = mechanism;

        if (_mechanism) {

            [_mechanism beginAuthenticationExchangeWithResponseHandler:^(NSData *initialResponse, BOOL abort) {
                dispatch_async(queue, ^{

                    PXDocument *request = nil;

                    if (abort) {
                        if ([delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
                            NSError *error = [NSError errorWithDomain:XMPPStreamFeatureSASLErrorDomain
                                                                 code:XMPPStreamFeatureSASLErrorCodeAborted
                                                             userInfo:nil];
                            [delegate streamFeature:self didFailNegotiationWithError:error];
                        }
                    } else {
                        request = [[PXDocument alloc] initWithElementName:@"auth"
                                                                namespace:XMPPStreamFeatureSASLNamespace
                                                                   prefix:nil];

                        [request.root setValue:[[mechanism class] name] forAttribute:@"mechanism"];

                        if (initialResponse) {
                            NSString *initialResponseString = [initialResponse base64EncodedStringWithOptions:0];
                            [request.root setStringValue:initialResponseString];
                        }

                        if ([delegate respondsToSelector:@selector(streamFeature:handleElement:)]) {
                            [delegate streamFeature:self handleElement:request.root];
                        }
                    }

                });
            }];
        
        } else {
            
            NSError *error = [NSError errorWithDomain:XMPPStreamFeatureSASLErrorDomain
                                                 code:XMPPStreamFeatureSASLErrorCodeInvalidMechanism
                                             userInfo:nil];
            if ([delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
                [delegate streamFeature:self didFailNegotiationWithError:error];
            }
        }
    }
}

- (void)handleElement:(PXElement *)element
{
    if ([element.namespace isEqualToString:XMPPStreamFeatureSASLNamespace]) {

        if ([element.name isEqualToString:@"success"]) {

            [self xmpp_handleSuccess];

        } else if ([element.name isEqualToString:@"failure"]) {

            NSError *error = [[self class] errorFromElement:element];
            [self xmpp_handleFailureWithError:error];

        } else if ([element.name isEqualToString:@"challenge"]) {

            NSString *challengeString = element.stringValue;
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

                                if ([self.delegate respondsToSelector:@selector(streamFeature:handleElement:)]) {
                                    [self.delegate streamFeature:self handleElement:response.root];
                                }
                            });
                        }];
        }
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

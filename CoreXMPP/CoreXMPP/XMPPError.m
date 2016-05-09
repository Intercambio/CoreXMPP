//
//  XMPPError.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 24.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPError.h"

NSString *const XMPPErrorDomain = @"XMPPErrorDomain";
NSString *const XMPPDispatcherErrorDomain = @"XMPPDispatcherErrorDomain";
NSString *const XMPPStreamFeatureSASLErrorDomain = @"XMPPStreamFeatureSASLErrorDomain";
NSString *const XMPPStreamErrorDomain = @"XMPPStreamErrorDomain";
NSString *const XMPPStanzaErrorDomain = @"XMPPStanzaErrorDomain";

NSString *const XMPPErrorXMLDocumentKey = @"XMPPErrorXMLDocumentKey";
NSString *const XMPPErrorUnderlyingErrorsKey = @"XMPPErrorUnderlyingErrorsKey";

@implementation NSError (XMPP)

#pragma mark Stream Errors

+ (NSError *)streamErrorFromElement:(PXElement *)element
{
    if ([element.namespace isEqualToString:@"http://etherx.jabber.org/streams"] &&
        [element.name isEqualToString:@"error"]) {

        NSMutableArray *children = [[NSMutableArray alloc] init];
        [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
            [children addObject:element];
        }];

        NSString *errorDomain = XMPPStreamErrorDomain;
        __block NSInteger errorCode = XMPPStreamErrorCodeUndefinedCondition;
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

        PXDocument *errorDocument = [[PXDocument alloc] initWithElement:element];
        [userInfo setObject:errorDocument forKey:XMPPErrorXMLDocumentKey];

        PXElement *errorElement = [children firstObject];
        if ([errorElement.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-streams"]) {

            NSDictionary *errorCodes = @{ @"bad-format" : @(XMPPStreamErrorCodeBadFormat),
                                          @"bad-namespace-prefix" : @(XMPPStreamErrorCodeBadNamespacePrefix),
                                          @"conflict" : @(XMPPStreamErrorCodeConflict),
                                          @"connection-timeout" : @(XMPPStreamErrorCodeConnectionTimeout),
                                          @"host-gone" : @(XMPPStreamErrorCodeHostGone),
                                          @"host-unknown" : @(XMPPStreamErrorCodeHostUnknown),
                                          @"improper-addressing" : @(XMPPStreamErrorCodeImproperAddressing),
                                          @"internal-server-error" : @(XMPPStreamErrorCodeInternalServerError),
                                          @"invalid-from" : @(XMPPStreamErrorCodeInvalidFrom),
                                          @"invalid-namespace" : @(XMPPStreamErrorCodeInvalidNamespace),
                                          @"invalid-xml" : @(XMPPStreamErrorCodeInvalidXML),
                                          @"not-authorized" : @(XMPPStreamErrorCodeNotAuthorized),
                                          @"not-well-formed" : @(XMPPStreamErrorCodeNotWellFormed),
                                          @"policy-violation" : @(XMPPStreamErrorCodePolicyViolation),
                                          @"remote-connection-failed" : @(XMPPStreamErrorCodeRemoteConnectionFailed),
                                          @"reset" : @(XMPPStreamErrorCodeReset),
                                          @"resource-constraint" : @(XMPPStreamErrorCodeResourceConstraint),
                                          @"restricted-xml" : @(XMPPStreamErrorCodeRestrictedXML),
                                          @"see-other-host" : @(XMPPStreamErrorCodeSeeOtherHost),
                                          @"system-shutdown" : @(XMPPStreamErrorCodeSystemShutdown),
                                          @"undefined-condition" : @(XMPPStreamErrorCodeUndefinedCondition),
                                          @"unsupported-encoding" : @(XMPPStreamErrorCodeUnsupportedEncoding),
                                          @"unsupported-feature" : @(XMPPStreamErrorCodeUnsupportedFeature),
                                          @"unsupported-stanza-type" : @(XMPPStreamErrorCodeUnsupportedStanzaType),
                                          @"unsupported-version" : @(XMPPStreamErrorCodeUnsupportedVersion) };

            errorCode = [errorCodes[errorElement.name] integerValue] ?: XMPPStreamErrorCodeUndefinedCondition;
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

#pragma mark Stanza Errors

+ (NSDictionary *)xmpp_stanzaErrorCodesByErrorName
{
    return @{ @"bad-request" : @(XMPPStanzaErrorCodeBadRequest),
              @"conflict" : @(XMPPStanzaErrorCodeConflict),
              @"feature-not-implemented" : @(XMPPStanzaErrorCodeFeatureNotImplemented),
              @"forbidden" : @(XMPPStanzaErrorCodeForbidden),
              @"gone" : @(XMPPStanzaErrorCodeGone),
              @"internal-server-error" : @(XMPPStanzaErrorCodeInternalServerError),
              @"item-not-found" : @(XMPPStanzaErrorCodeItemNotFound),
              @"jid-malformed" : @(XMPPStanzaErrorCodeJIDMalformed),
              @"not-acceptable" : @(XMPPStanzaErrorCodeNotAcceptable),
              @"not-allowed" : @(XMPPStanzaErrorCodeNotAllowed),
              @"not-authorized" : @(XMPPStanzaErrorCodeNotAuthorithed),
              @"policy-violation" : @(XMPPStanzaErrorCodePolicyViolation),
              @"recipient-unavailable" : @(XMPPStanzaErrorCodeRecipientUnavailable),
              @"redirect" : @(XMPPStanzaErrorCodeRedirect),
              @"registration-required" : @(XMPPStanzaErrorCodeRegistrationRequired),
              @"remote-server-not-found" : @(XMPPStanzaErrorCodeRemoteServerNotFound),
              @"remote-server-timeout" : @(XMPPStanzaErrorCodeRemoteServerTimeout),
              @"resource-constraint" : @(XMPPStanzaErrorCodeResourceConstraint),
              @"service-unavailable" : @(XMPPStanzaErrorCodeServiceUnavailable),
              @"subscription-required" : @(XMPPStanzaErrorCodeSubscriptionRequired),
              @"undefined-condition" : @(XMPPStanzaErrorCodeUndefinedCondition),
              @"unexpected-request" : @(XMPPStanzaErrorCodeUnexpectedRequest) };
}

+ (NSDictionary *)xmpp_descriptionByStanzaErrorCodes
{
    return @{ @(XMPPStanzaErrorCodeBadRequest): @"Bad Request",
              @(XMPPStanzaErrorCodeConflict): @"Conflict",
              @(XMPPStanzaErrorCodeFeatureNotImplemented): @"Feature not implemented",
              @(XMPPStanzaErrorCodeForbidden): @"Forbidden",
              @(XMPPStanzaErrorCodeGone): @"Gone",
              @(XMPPStanzaErrorCodeInternalServerError): @"Internal Server Error",
              @(XMPPStanzaErrorCodeItemNotFound): @"Item not found",
              @(XMPPStanzaErrorCodeJIDMalformed): @"JID malformed",
              @(XMPPStanzaErrorCodeNotAcceptable): @"Not acceptable",
              @(XMPPStanzaErrorCodeNotAllowed): @"Not allowed",
              @(XMPPStanzaErrorCodeNotAuthorithed): @"Not authorized",
              @(XMPPStanzaErrorCodePolicyViolation): @"Policy violation",
              @(XMPPStanzaErrorCodeRecipientUnavailable): @"Recipient unavailable",
              @(XMPPStanzaErrorCodeRedirect): @"Redirect",
              @(XMPPStanzaErrorCodeRegistrationRequired): @"Registration required",
              @(XMPPStanzaErrorCodeRemoteServerNotFound): @"Remote Server not found",
              @(XMPPStanzaErrorCodeRemoteServerTimeout): @"Remote Server Timeout",
              @(XMPPStanzaErrorCodeResourceConstraint): @"Resource Constraint",
              @(XMPPStanzaErrorCodeServiceUnavailable): @"Service unavailable",
              @(XMPPStanzaErrorCodeSubscriptionRequired): @"Subscription required",
              @(XMPPStanzaErrorCodeUndefinedCondition): @"Undefined Condition",
              @(XMPPStanzaErrorCodeUnexpectedRequest): @"Unexpected Request" };
}

+ (NSInteger)stanzaErrorCodeWithName:(NSString *)name
{
    NSNumber *_code = [[self xmpp_stanzaErrorCodesByErrorName] objectForKey:name];
    return _code ? [_code integerValue] : XMPPStanzaErrorCodeUndefinedCondition;
}

+ (NSError *)errorFromElement:(PXElement *)errorElement
{
    if (errorElement) {

        NSMutableArray *children = [[NSMutableArray alloc] init];
        [errorElement enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
            [children addObject:element];
        }];

        NSString *errorDomain = XMPPStanzaErrorDomain;
        __block NSInteger errorCode = XMPPStanzaErrorCodeUndefinedCondition;
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

        PXElement *definedCondition = [children firstObject];
        if ([definedCondition.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-stanzas"]) {

            NSDictionary *errorCodes = [self xmpp_stanzaErrorCodesByErrorName];

            errorCode = [errorCodes[definedCondition.name] integerValue] ?: XMPPStanzaErrorCodeUndefinedCondition;
        }

        if ([children count] >= 2) {
            PXElement *errorText = [children objectAtIndex:1];
            if ([errorText.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-stanzas"] &&
                [errorText.name isEqualToString:@"text"]) {
                [userInfo setObject:errorText.stringValue forKey:NSLocalizedDescriptionKey];
            }
        }

        return [NSError errorWithDomain:errorDomain
                                   code:errorCode
                               userInfo:userInfo];

    } else {
        return nil;
    }
}

+ (NSError *)errorFromStanza:(PXElement *)element
{
    __block PXElement *errorElement = nil;
    [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
        if ([element.namespace isEqualToString:@"jabber:client"] &&
            [element.name isEqualToString:@"error"]) {
            errorElement = element;
            *stop = YES;
        }
    }];

    if (errorElement) {

        NSMutableArray *children = [[NSMutableArray alloc] init];
        [errorElement enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
            [children addObject:element];
        }];

        NSString *errorDomain = XMPPStanzaErrorDomain;
        __block NSInteger errorCode = XMPPStanzaErrorCodeUndefinedCondition;
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

        PXDocument *errorDocument = [[PXDocument alloc] initWithElement:element];
        [userInfo setObject:errorDocument forKey:XMPPErrorXMLDocumentKey];

        PXElement *definedCondition = [children firstObject];
        if ([definedCondition.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-stanzas"]) {

            NSDictionary *errorCodes = [self xmpp_stanzaErrorCodesByErrorName];

            errorCode = [errorCodes[definedCondition.name] integerValue] ?: XMPPStanzaErrorCodeUndefinedCondition;
        }

        if ([children count] >= 2) {
            PXElement *errorText = [children objectAtIndex:1];
            if ([errorText.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-stanzas"] &&
                [errorText.name isEqualToString:@"text"]) {
                [userInfo setObject:errorText.stringValue forKey:NSLocalizedDescriptionKey];
            }
        }

        if ([userInfo valueForKey:NSLocalizedDescriptionKey] == nil) {
            NSDictionary *errorDescriptions = [[self class] xmpp_descriptionByStanzaErrorCodes];
            NSString *errorText = NSLocalizedString([errorDescriptions objectForKey:@(errorCode)], nil);
            [userInfo setObject:errorText forKey:NSLocalizedDescriptionKey];
        }
        
        return [NSError errorWithDomain:errorDomain
                                   code:errorCode
                               userInfo:userInfo];

    } else {
        return nil;
    }
}

+ (PXElement *)IQResponseWithError:(NSError *)error
{
    NSUInteger errorCode = XMPPStanzaErrorCodeUndefinedCondition;
    if ([error.domain isEqualToString:XMPPStanzaErrorDomain]) {
        errorCode = error.code;
    }

    NSDictionary *errorCodes = [self xmpp_stanzaErrorCodesByErrorName];

    NSString *errorName = [[errorCodes keysOfEntriesPassingTest:^BOOL(NSString *name, NSNumber *code, BOOL *stop) {
        return [code integerValue] == errorCode;
    }] anyObject];

    if (errorName == nil) {
        errorName = @"undefined-condition";
    }

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *response = doc.root;
    [response setValue:@"error" forAttribute:@"type"];

    PXElement *errorElement = [response addElementWithName:@"error" namespace:@"jabber:client" content:nil];
    [errorElement addElementWithName:errorName namespace:@"urn:ietf:params:xml:ns:xmpp-stanzas" content:nil];

    return response;
}

@end

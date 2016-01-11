//
//  XMPPStanza.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanza.h"

NSString *const XMPPStanzaErrorDomain = @"XMPPStanzaErrorDomain";
NSString *const XMPPStanzaErrorXMLDocumentKey = @"XMPPStanzaErrorXMLDocumentKey";

@implementation XMPPStanza

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
        [userInfo setObject:errorDocument forKey:XMPPStanzaErrorXMLDocumentKey];

        PXElement *definedCondition = [children firstObject];
        if ([definedCondition.namespace isEqualToString:@"urn:ietf:params:xml:ns:xmpp-stanzas"]) {

            NSDictionary *errorCodes = @{ @"bad-request" : @(XMPPStanzaErrorCodeBadRequest),
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

@end

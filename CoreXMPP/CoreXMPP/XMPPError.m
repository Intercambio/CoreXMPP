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

@end

//
//  XMPPError.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 24.01.16.
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

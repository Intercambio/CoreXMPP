//
//  XMPPStanza.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

extern NSString * const XMPPStanzaErrorDomain;

typedef NS_ENUM(NSInteger, XMPPStanzaErrorCode) {
    XMPPStanzaErrorCodeBadRequest, // bad-request
    XMPPStanzaErrorCodeConflict, // conflict
    XMPPStanzaErrorCodeFeatureNotImplemented, // feature-not-implemented
    XMPPStanzaErrorCodeForbidden, // forbidden
    XMPPStanzaErrorCodeGone, // gone
    XMPPStanzaErrorCodeInternalServerError, // internal-server-error
    XMPPStanzaErrorCodeItemNotFound, // item-not-found
    XMPPStanzaErrorCodeJIDMalformed, // jid-malformed
    XMPPStanzaErrorCodeNotAcceptable, // not-acceptable
    XMPPStanzaErrorCodeNotAllowed, // not-allowed
    XMPPStanzaErrorCodeNotAuthorithed, // not-authorized
    XMPPStanzaErrorCodePolicyViolation, // policy-violation
    XMPPStanzaErrorCodeRecipientUnavailable, // recipient-unavailable
    XMPPStanzaErrorCodeRedirect, // redirect
    XMPPStanzaErrorCodeRegistrationRequired, // registration-required
    XMPPStanzaErrorCodeRemoteServerNotFound, // remote-server-not-found
    XMPPStanzaErrorCodeRemoteServerTimeout, // remote-server-timeout
    XMPPStanzaErrorCodeResourceConstraint, // resource-constraint
    XMPPStanzaErrorCodeServiceUnavailable, // service-unavailable
    XMPPStanzaErrorCodeSubscriptionRequired, // subscription-required
    XMPPStanzaErrorCodeUndefinedCondition, // undefined-condition
    XMPPStanzaErrorCodeUnexpectedRequest // unexpected-request
};

extern NSString * const XMPPStanzaErrorXMLDocumentKey;


@interface XMPPStanza : NSObject

+ (NSError *)errorFromStanza:(PXElement *)element;

@end

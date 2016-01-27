//
//  XMPPError.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 24.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const XMPPErrorDomain;

typedef NS_ENUM(NSInteger, XMPPErrorCode) {
    XMPPErrorCodeUnknown,
    XMPPErrorCodeInvalidState,

    // Replace with more general error codes
    XMPPErrorCodeParseError,
    XMPPErrorCodeDiscoveryError,
    XMPPErrorCodeMessageFormatError,
};

extern NSString *const XMPPErrorXMLDocumentKey;
extern NSString *const XMPPErrorUnderlyingErrorsKey;

// Dispatcher

extern NSString *const XMPPDispatcherErrorDomain;

typedef NS_ENUM(NSInteger, XMPPDispatcherErrorCode) {
    XMPPDispatcherErrorCodeTimeout,
    XMPPDispatcherErrorCodeNoSender,
    XMPPDispatcherErrorCodeNoRoute,
    XMPPDispatcherErrorCodeNotConnected,
    XMPPDispatcherErrorCodeInvalidStanza
};

// XMPPStreamFeature SASL

extern NSString *const XMPPStreamFeatureSASLErrorDomain;

typedef NS_ENUM(NSInteger, XMPPStreamFeatureSASLErrorCode) {
    XMPPStreamFeatureSASLErrorCodeUndefined,
    XMPPStreamFeatureSASLErrorCodeAborted,
    XMPPStreamFeatureSASLErrorCodeAccountDisabled,
    XMPPStreamFeatureSASLErrorCodeCredentialsExpired,
    XMPPStreamFeatureSASLErrorCodeEncryptionRequired,
    XMPPStreamFeatureSASLErrorCodeIncorrectEncoding,
    XMPPStreamFeatureSASLErrorCodeInvalidAuthzid,
    XMPPStreamFeatureSASLErrorCodeInvalidMechanism,
    XMPPStreamFeatureSASLErrorCodeMalformedRequest,
    XMPPStreamFeatureSASLErrorCodeMechanismTooWeak,
    XMPPStreamFeatureSASLErrorCodeNotAuthorized,
    XMPPStreamFeatureSASLErrorCodeTemporaryAuthFailure
};

// Stream

extern NSString *const XMPPStreamErrorDomain;

typedef NS_ENUM(NSInteger, XMPPStreamErrorCode) {
    XMPPStreamErrorCodeBadFormat,
    XMPPStreamErrorCodeBadNamespacePrefix,
    XMPPStreamErrorCodeConflict,
    XMPPStreamErrorCodeConnectionTimeout,
    XMPPStreamErrorCodeHostGone,
    XMPPStreamErrorCodeHostUnknown,
    XMPPStreamErrorCodeImproperAddressing,
    XMPPStreamErrorCodeInternalServerError,
    XMPPStreamErrorCodeInvalidFrom,
    XMPPStreamErrorCodeInvalidNamespace,
    XMPPStreamErrorCodeInvalidXML,
    XMPPStreamErrorCodeNotAuthorized,
    XMPPStreamErrorCodeNotWellFormed,
    XMPPStreamErrorCodePolicyViolation,
    XMPPStreamErrorCodeRemoteConnectionFailed,
    XMPPStreamErrorCodeReset,
    XMPPStreamErrorCodeResourceConstraint,
    XMPPStreamErrorCodeRestrictedXML,
    XMPPStreamErrorCodeSeeOtherHost,
    XMPPStreamErrorCodeSystemShutdown,
    XMPPStreamErrorCodeUndefinedCondition,
    XMPPStreamErrorCodeUnsupportedEncoding,
    XMPPStreamErrorCodeUnsupportedFeature,
    XMPPStreamErrorCodeUnsupportedStanzaType,
    XMPPStreamErrorCodeUnsupportedVersion
};

// Stanza

extern NSString *const XMPPStanzaErrorDomain;

typedef NS_ENUM(NSInteger, XMPPStanzaErrorCode) {
    XMPPStanzaErrorCodeBadRequest,            // bad-request
    XMPPStanzaErrorCodeConflict,              // conflict
    XMPPStanzaErrorCodeFeatureNotImplemented, // feature-not-implemented
    XMPPStanzaErrorCodeForbidden,             // forbidden
    XMPPStanzaErrorCodeGone,                  // gone
    XMPPStanzaErrorCodeInternalServerError,   // internal-server-error
    XMPPStanzaErrorCodeItemNotFound,          // item-not-found
    XMPPStanzaErrorCodeJIDMalformed,          // jid-malformed
    XMPPStanzaErrorCodeNotAcceptable,         // not-acceptable
    XMPPStanzaErrorCodeNotAllowed,            // not-allowed
    XMPPStanzaErrorCodeNotAuthorithed,        // not-authorized
    XMPPStanzaErrorCodePolicyViolation,       // policy-violation
    XMPPStanzaErrorCodeRecipientUnavailable,  // recipient-unavailable
    XMPPStanzaErrorCodeRedirect,              // redirect
    XMPPStanzaErrorCodeRegistrationRequired,  // registration-required
    XMPPStanzaErrorCodeRemoteServerNotFound,  // remote-server-not-found
    XMPPStanzaErrorCodeRemoteServerTimeout,   // remote-server-timeout
    XMPPStanzaErrorCodeResourceConstraint,    // resource-constraint
    XMPPStanzaErrorCodeServiceUnavailable,    // service-unavailable
    XMPPStanzaErrorCodeSubscriptionRequired,  // subscription-required
    XMPPStanzaErrorCodeUndefinedCondition,    // undefined-condition
    XMPPStanzaErrorCodeUnexpectedRequest      // unexpected-request
};

@class PXElement;

@interface NSError (XMPP)
+ (NSError *)streamErrorFromElement:(PXElement *)element;
+ (NSInteger)stanzaErrorCodeWithName:(NSString *)name;
+ (NSError *)errorFromStanza:(PXElement *)element;
+ (NSError *)errorFromElement:(PXElement *)errorElement;
+ (PXElement *)IQResponseWithError:(NSError *)error;
@end

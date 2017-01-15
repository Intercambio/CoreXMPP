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
    XMPPErrorCodeAccountExists,

    // Replace with more general error codes
    XMPPErrorCodeParseError,
    XMPPErrorCodeDiscoveryError,
    XMPPErrorCodeMessageFormatError,
};

extern NSString *const XMPPErrorXMLDocumentKey;
extern NSString *const XMPPErrorUnderlyingErrorsKey;


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

@class PXDocument;
@class PXElement;

@interface NSError (XMPP)
+ (NSError *)streamErrorFromElement:(PXElement *)element;
@end

//
//  XMPPStreamFeatureSASL.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeature.h"
#import "SASLMechanism.h"

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

extern NSString *const XMPPStreamFeatureSASLNamespace;

@protocol XMPPStreamFeatureDelegateSASL <XMPPStreamFeatureDelegate>
@optional
- (SASLMechanism *)SASLMechanismForStreamFeature:(XMPPStreamFeature *)streamFeature supportedMechanisms:(NSArray *)mechanisms;
@end

@interface XMPPStreamFeatureSASL : XMPPStreamFeature

#pragma mark SASL Errors
+ (NSError *)errorFromElement:(PXElement *)element;

#pragma mark Mechanisms
@property (nonatomic, readonly) NSArray *mechanisms;

@end

//
//  XMPPStreamFeatureSASL.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeature.h"
#import <SASLKit/SASLKit.h>

extern NSString *_Nonnull const XMPPStreamFeatureSASLNamespace NS_SWIFT_NAME(StreamFeatureSASLNamespace);

NS_SWIFT_NAME(StreamFeatureDelegateSASL)
@protocol XMPPStreamFeatureDelegateSASL <XMPPStreamFeatureDelegate>
@optional
- (nullable SASLMechanism *)SASLMechanismForStreamFeature:(nonnull XMPPStreamFeature *)streamFeature
                                      supportedMechanisms:(nonnull NSArray<NSString *> *)mechanisms NS_SWIFT_NAME(SASLMechanismForStreamFeature(_:supportedMechanisms:));
@end

NS_SWIFT_NAME(StreamFeatureSASL)
@interface XMPPStreamFeatureSASL : XMPPStreamFeature

#pragma mark SASL Errors
+ (nullable NSError *)errorFromElement:(nonnull PXElement *)element;

#pragma mark Mechanisms
@property (nonatomic, readonly) NSArray *_Nonnull mechanisms;

@end

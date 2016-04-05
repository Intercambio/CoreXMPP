//
//  XMPPStreamFeatureSASL.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanism.h"
#import "XMPPStreamFeature.h"

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

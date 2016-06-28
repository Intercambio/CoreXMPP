//
//  XMPPInBandRegistration.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPRegistrationChallenge.h"
#import "XMPPStreamFeature.h"

extern NSString *const XMPPInBandRegistrationNamespace;

@protocol XMPPStreamFeatureDelegateInBandRegistration <XMPPStreamFeatureDelegate>
@optional
- (void)streamFeature:(XMPPStreamFeature *)streamFeature didReceiveRegistrationChallenge:(id<XMPPRegistrationChallenge>)challenge;
@end

@interface XMPPInBandRegistration : XMPPStreamFeature

@end

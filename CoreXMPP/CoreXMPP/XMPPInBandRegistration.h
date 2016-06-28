//
//  XMPPInBandRegistration.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDataForm.h"
#import "XMPPStreamFeature.h"

extern NSString *const XMPPInBandRegistrationNamespace;

@protocol XMPPRegistrationChallenge <NSObject>
- (XMPPDataForm *)registrationForm;
- (void)submitRegistration:(XMPPDataForm *)registrationForm
                completion:(void (^)(BOOL success, NSError *error))completion;
@end

@protocol XMPPStreamFeatureDelegateInBandRegistration <XMPPStreamFeatureDelegate>
@optional
- (void)streamFeature:(XMPPStreamFeature *)streamFeature didReceiveRegistrationChallenge:(id<XMPPRegistrationChallenge>)challenge;
@end

@interface XMPPInBandRegistration : XMPPStreamFeature

@end

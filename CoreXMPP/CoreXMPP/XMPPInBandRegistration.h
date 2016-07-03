//
//  XMPPInBandRegistration.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPRegistrationChallenge.h"
#import "XMPPStreamFeature.h"

extern NSString *_Nonnull const XMPPInBandRegistrationNamespace NS_SWIFT_NAME(InBandRegistrationNamespace);

NS_SWIFT_NAME(StreamFeatureDelegateInBandRegistration)
@protocol XMPPStreamFeatureDelegateInBandRegistration <XMPPStreamFeatureDelegate>
@optional
- (void)streamFeature:(nonnull XMPPStreamFeature *)streamFeature didReceiveRegistrationChallenge:(nonnull id<XMPPRegistrationChallenge>)challenge NS_SWIFT_NAME(streamFeature(_:didReceive:));
- (void)streamFeature:(nonnull XMPPStreamFeature *)streamFeature didRegisterWithUsername:(nullable NSString *)username hostname:(nonnull NSString *)hostname NS_SWIFT_NAME(streamFeature(_:didRegisterUsername:hostname:));
@end

NS_SWIFT_NAME(InBandRegistration)
@interface XMPPInBandRegistration : XMPPStreamFeature

@end

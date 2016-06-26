//
//  XMPPInBandRegistration.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

extern NSString * const XMPPInBandRegistrationNamespace;

@protocol XMPPStreamFeatureDelegateInBandRegistration <XMPPStreamFeatureDelegate>
@optional

@end

@interface XMPPInBandRegistration : XMPPStreamFeature

@end

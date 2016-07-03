//
//  XMPPRegistrationChallenge.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 28.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

NS_SWIFT_NAME(RegistrationChallenge)
@protocol XMPPRegistrationChallenge <NSObject>
- (nullable PXDocument *)registrationForm;
- (void)submitRegistration:(nonnull PXDocument *)registrationForm
                completion:(nonnull void (^)(BOOL success, NSError *_Nullable error))completion NS_SWIFT_NAME(submitRegistration(_:completion:));
@end

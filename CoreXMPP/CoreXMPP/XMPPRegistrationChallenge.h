//
//  XMPPRegistrationChallenge.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 28.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

@protocol XMPPRegistrationChallenge <NSObject>
- (PXDocument *)registrationForm;
- (void)submitRegistration:(PXDocument *)registrationForm
                completion:(void (^)(BOOL success, NSError *error))completion;
@end

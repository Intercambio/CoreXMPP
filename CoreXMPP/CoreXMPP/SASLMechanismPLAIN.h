//
//  SASLMechanismPLAIN.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanism.h"

@protocol SASLMechanismDelegatePLAIN <SASLMechanismDelegate>
- (void)SASLMechanismNeedsCredentials:(SASLMechanism *)mechanism;
@end

@interface SASLMechanismPLAIN : SASLMechanism

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password;

- (void)abort;

@end

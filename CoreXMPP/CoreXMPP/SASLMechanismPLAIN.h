//
//  SASLMechanismPLAIN.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanism.h"

@interface SASLMechanismPLAIN : SASLMechanism

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password;

- (void)abort;

@end

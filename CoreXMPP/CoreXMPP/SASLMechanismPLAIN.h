//
//  SASLMechanismPLAIN.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanism.h"

@interface SASLMechanismPLAIN : SASLMechanism

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password DEPRECATED_ATTRIBUTE;
- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(BOOL success, NSError *error))completion;
- (void)abort;

@end

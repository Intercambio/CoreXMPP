//
//  SASLMechanism.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanism.h"

@implementation SASLMechanism

+ (NSString *)name
{
    return nil;
}

- (void)beginAuthenticationExchangeWithResponseHandler:(void (^)(NSData *, BOOL))responseHandler
{
    if (responseHandler) {
        responseHandler(nil, YES);
    }
}

- (void)handleChallenge:(NSString *)challenge responseHandler:(void (^)(NSData *, BOOL))responseHandler
{
    if (responseHandler) {
        responseHandler(nil, YES);
    }
}

@end

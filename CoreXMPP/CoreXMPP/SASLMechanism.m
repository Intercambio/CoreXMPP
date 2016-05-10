//
//  SASLMechanism.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanism.h"

NSString *const SASLMechanismErrorDomain = @"SASLMechanismErrorDomain";

@implementation SASLMechanism

#pragma mark Registered Mechanisms

+ (NSMutableDictionary *)sasl_registeredMechanisms
{
    static NSMutableDictionary *registeredMechanisms;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registeredMechanisms = [[NSMutableDictionary alloc] init];
    });
    return registeredMechanisms;
}

+ (NSDictionary *)registeredMechanisms
{
    return [self sasl_registeredMechanisms];
}

+ (void)registerMechanismClass:(Class)mechanismClass forMechanismName:(NSString *)mechanismName
{
    [[self sasl_registeredMechanisms] setObject:mechanismClass forKey:mechanismName];
}

#pragma mark Mechanism Name

+ (NSString *)name
{
    return nil;
}

#pragma mark Authentication Exchange

- (void)beginAuthenticationExchangeWithHostname:(NSString *)hostname responseHandler:(void (^)(NSData *initialResponse, BOOL abort))responseHandler
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

#pragma mark Authentication Outcome

- (void)succeedWithData:(NSData *)data
{
}

- (void)failedWithError:(NSError *)error
{
}

@end

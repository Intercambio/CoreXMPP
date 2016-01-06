//
//  SASLMechanism.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SASLMechanism;

@protocol SASLMechanismDelegate <NSObject>

@end

@interface SASLMechanism : NSObject

+ (NSString *)name;

@property (nonatomic, weak) id<SASLMechanismDelegate> delegate;

- (void)beginAuthenticationExchangeWithResponseHandler:(void (^)(NSData *initialResponse, BOOL abort))responseHandler;
- (void)handleChallenge:(NSData *)challenge
        responseHandler:(void (^)(NSData *response, BOOL abort))responseHandler;

@end

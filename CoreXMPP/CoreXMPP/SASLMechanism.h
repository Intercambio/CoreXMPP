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
@optional
- (void)SASLMechanismNeedsCredentials:(SASLMechanism *)mechanism;
@end

@interface SASLMechanism : NSObject

#pragma mark Registered Mechanisms
+ (NSDictionary *)registeredMechanisms;
+ (void)registerMechanismClass:(Class)mechanismClass forMechanismName:(NSString *)mechanismName;

#pragma mark Mechanism Name
+ (NSString *)name;

#pragma mark Delegate
@property (nonatomic, weak) id<SASLMechanismDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;

#pragma mark Context
@property (nonatomic, strong) id context;

#pragma mark Authentication Exchange
- (void)beginAuthenticationExchangeWithHostname:(NSString *)hostname
                                responseHandler:(void (^)(NSData *initialResponse, BOOL abort))responseHandler;
- (void)handleChallenge:(NSData *)challenge
        responseHandler:(void (^)(NSData *response, BOOL abort))responseHandler;

@end

//
//  SASLMechanismPLAIN.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "SASLMechanismPLAIN.h"

@interface SASLMechanismPLAIN () {
    dispatch_queue_t _queue;
    void(^_responseHandler)(NSData *response, BOOL abort);
}

@end

@implementation SASLMechanismPLAIN

+ (NSString *)name
{
    return @"PLAIN";
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("SASLMechanismPLAIN", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)beginAuthenticationExchangeWithResponseHandler:(void (^)(NSData *initialResponse, BOOL abort))responseHandler
{
    dispatch_async(_queue, ^{
        _responseHandler = responseHandler;
        if ([self.delegate conformsToProtocol:@protocol(SASLMechanismDelegatePLAIN)]) {
            id<SASLMechanismDelegatePLAIN> delegate = (id<SASLMechanismDelegatePLAIN>)self.delegate;
            [delegate SASLMechanismNeedsCredentials:self];
        }
    });
}

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
{
    dispatch_async(_queue, ^{
        if (_responseHandler) {
            if (username && password) {
                
                unsigned short nul[] = { 0 };
                
                NSMutableData *response = [[NSMutableData alloc] init];
                
                [response appendBytes:nul length:1];
                [response appendData:[username dataUsingEncoding:NSUTF8StringEncoding]];
                
                [response appendBytes:nul length:1];
                [response appendData:[password dataUsingEncoding:NSUTF8StringEncoding]];
                
                _responseHandler(response, NO);
            } else {
                _responseHandler(nil, YES);
            }
            _responseHandler = nil;
        }
    });
}

- (void)abort
{
    dispatch_async(_queue, ^{
        if (_responseHandler) {
            _responseHandler(nil, YES);
            _responseHandler = nil;
        }
    });
}

@end

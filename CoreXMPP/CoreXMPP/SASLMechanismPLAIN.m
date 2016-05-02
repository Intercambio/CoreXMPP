//
//  SASLMechanismPLAIN.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

static DDLogLevel ddLogLevel = DDLogLevelWarning;

#import "SASLMechanismPLAIN.h"

@interface SASLMechanismPLAIN () {
    dispatch_queue_t _queue;
    NSString *_hostname;
    void (^_responseHandler)(NSData *response, BOOL abort);
    void (^_completion)(BOOL success, NSError *error);
}

@end

@implementation SASLMechanismPLAIN

+ (void)load
{
    [SASLMechanism registerMechanismClass:self
                         forMechanismName:[self name]];
}

+ (DDLogLevel)ddLogLevel
{
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel
{
    ddLogLevel = logLevel;
}

#pragma mark Mechanism Name

+ (NSString *)name
{
    return @"PLAIN";
}

#pragma mark Life-cycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("SASLMechanismPLAIN", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark Authenticate

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                      completion:(void (^)(BOOL success, NSError *error))completion
{
    dispatch_async(_queue, ^{
        if (_responseHandler) {
            if (username && password) {

                _completion = completion;

                DDLogInfo(@"Authenticate with username (%@) and password (...) for '%@'.", username, _hostname);

                unsigned short nul[] = {0};

                NSMutableData *response = [[NSMutableData alloc] init];

                [response appendBytes:nul length:1];
                [response appendData:[username dataUsingEncoding:NSUTF8StringEncoding]];

                [response appendBytes:nul length:1];
                [response appendData:[password dataUsingEncoding:NSUTF8StringEncoding]];

                _responseHandler(response, NO);
            } else {

                DDLogWarn(@"Abort authentication for '%@', because either username or password is nil.", _hostname);

                _responseHandler(nil, YES);

                if (completion) {
                    NSString *errorMessage = [NSString stringWithFormat:@"Abort authentication for '%@', because either username or password is nil.", _hostname];
                    NSError *error = [NSError errorWithDomain:SASLMechanismErrorDomain
                                                         code:SASLMechanismErrorCodeNoCredentials
                                                     userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
                    completion(NO, error);
                }
            }
            _responseHandler = nil;
        }
    });
}

- (void)abort
{
    dispatch_async(_queue, ^{
        if (_responseHandler) {

            DDLogWarn(@"Abort authentication for '%@'.", _hostname);

            _responseHandler(nil, YES);
            _responseHandler = nil;
        }
    });
}

#pragma mark Authentication Exchange

- (void)beginAuthenticationExchangeWithHostname:(NSString *)hostname responseHandler:(void (^)(NSData *, BOOL))responseHandler
{
    dispatch_async(_queue, ^{
        _hostname = hostname;
        _responseHandler = responseHandler;

        DDLogInfo(@"Begin authentication for '%@'.", hostname);

        dispatch_queue_t queue = self.delegateQueue ?: dispatch_get_main_queue();
        dispatch_async(queue, ^{
            if ([self.delegate respondsToSelector:@selector(SASLMechanismNeedsCredentials:)]) {
                [self.delegate SASLMechanismNeedsCredentials:self];
            }
        });
    });
}

#pragma mark Authentication Outcome

- (void)succeedWithData:(NSData *)data
{
    dispatch_async(_queue, ^{
        if (_completion) {
            void (^completion)(BOOL success, NSError *error) = _completion;
            dispatch_queue_t queue = self.delegateQueue ?: dispatch_get_main_queue();
            dispatch_async(queue, ^{
                completion(YES, nil);
            });
            _completion = nil;
        }
    });
}

- (void)failedWithError:(NSError *)error
{
    dispatch_async(_queue, ^{
        if (_completion) {
            void (^completion)(BOOL success, NSError *error) = _completion;
            dispatch_queue_t queue = self.delegateQueue ?: dispatch_get_main_queue();
            dispatch_async(queue, ^{
                completion(NO, error);
            });
            _completion = nil;
        }
    });
}

@end

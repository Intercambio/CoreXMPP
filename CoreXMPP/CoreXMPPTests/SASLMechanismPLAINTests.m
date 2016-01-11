//
//  SASLMechanismPLAINTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import <CoreXMPP/CoreXMPP.h>

@interface SASLMechanismPLAINTests : XCTestCase <SASLMechanismDelegatePLAIN>
@property (nonatomic, assign) BOOL abortAuthentication;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@end

@implementation SASLMechanismPLAINTests

- (void)setUp
{
    [super setUp];

    self.abortAuthentication = NO;
    self.username = nil;
    self.password = nil;
}

- (void)testWithCredentials
{
    self.username = @"romeo";
    self.password = @"123";

    SASLMechanismPLAIN *mechanism = [[SASLMechanismPLAIN alloc] init];
    mechanism.delegate = self;

    XCTestExpectation *expectResponse = [self expectationWithDescription:@"Expecting inital response"];

    [mechanism beginAuthenticationExchangeWithHostname:@"localhost"
                                       responseHandler:^(NSData *initialResponse, BOOL abort) {

                                           assertThatBool(abort, isFalse());

                                           unsigned short nul[] = {0};
                                           NSData *terminator = [NSData dataWithBytes:nul length:1];

                                           NSString *initialResponseString = [[NSString alloc] initWithData:initialResponse encoding:NSUTF8StringEncoding];
                                           NSString *terminatorString = [[NSString alloc] initWithData:terminator encoding:NSUTF8StringEncoding];

                                           NSArray *components = [initialResponseString componentsSeparatedByString:terminatorString];

                                           assertThat(components, hasCountOf(3));
                                           assertThat(components, contains(@"", @"romeo", @"123", nil));

                                           [expectResponse fulfill];
                                       }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testMissingCredentials
{
    self.username = @"romeo";

    SASLMechanismPLAIN *mechanism = [[SASLMechanismPLAIN alloc] init];
    mechanism.delegate = self;

    XCTestExpectation *expectResponse = [self expectationWithDescription:@"Expecting inital response"];

    [mechanism beginAuthenticationExchangeWithHostname:@"localhost"
                                       responseHandler:^(NSData *initialResponse, BOOL abort) {
                                           assertThatBool(abort, isTrue());

                                           [expectResponse fulfill];
                                       }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAbort
{
    self.abortAuthentication = YES;

    SASLMechanismPLAIN *mechanism = [[SASLMechanismPLAIN alloc] init];
    mechanism.delegate = self;

    XCTestExpectation *expectResponse = [self expectationWithDescription:@"Expecting inital response"];

    [mechanism beginAuthenticationExchangeWithHostname:@"localhost"
                                       responseHandler:^(NSData *initialResponse, BOOL abort) {
                                           assertThatBool(abort, isTrue());

                                           [expectResponse fulfill];
                                       }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark SASLMechanismDelegatePLAIN

- (void)SASLMechanismNeedsCredentials:(SASLMechanism *)mechanism
{
    if ([mechanism isKindOfClass:[SASLMechanismPLAIN class]]) {
        SASLMechanismPLAIN *plainMechanism = (SASLMechanismPLAIN *)mechanism;
        if (self.abortAuthentication) {
            [plainMechanism abort];
        } else {
            [plainMechanism authenticateWithUsername:self.username password:self.password];
        }
    }
}

@end

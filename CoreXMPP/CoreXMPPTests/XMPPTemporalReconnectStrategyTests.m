//
//  XMPPTemporalReconnectStrategyTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTemporalReconnectStrategy.h"
#import "XMPPTestCase.h"

@interface XMPPTemporalReconnectStrategyTests : XMPPTestCase
@property (nonatomic, strong) XMPPClient *client;
@property (nonatomic, strong) XMPPTemporalReconnectStrategy *strategy;
@end

@implementation XMPPTemporalReconnectStrategyTests

- (void)setUp
{
    [super setUp];
    self.client = mock([XMPPClient class]);
    self.strategy = [[XMPPTemporalReconnectStrategy alloc] initWithClient:self.client
                                                    reconnectTimeInterval:1.0];
}

#pragma mark Tests

- (void)testStrategy
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Connect"];
    [givenVoid([self.client connect]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];

    [self.strategy start];
    assertThat(self.strategy.nextConnectionAttempt, greaterThan([NSDate date]));

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end

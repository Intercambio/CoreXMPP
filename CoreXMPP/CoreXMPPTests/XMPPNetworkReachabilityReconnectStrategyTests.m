//
//  XMPPNetworkReachabilityReconnectStrategyTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPNetworkReachabilityReconnectStrategy.h"
#import "XMPPTestCase.h"

@interface XMPPNetworkReachabilityReconnectStrategyTests : XMPPTestCase
@property (nonatomic, strong) XMPPClient *client;
@property (nonatomic, strong) XMPPNetworkReachabilityReconnectStrategy *strategy;
@end

@implementation XMPPNetworkReachabilityReconnectStrategyTests

- (void)setUp
{
    [super setUp];
    self.client = mock([XMPPClient class]);
    self.strategy = [[XMPPNetworkReachabilityReconnectStrategy alloc] initWithClient:self.client
                                                                            hostname:@"localhost"];
}

- (void)tearDown
{
    stopMocking(self.client);
    [super tearDown];
}

#pragma mark Tests

- (void)testStrategy
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Connect"];
    [[givenVoid([self.client connect]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }] willDo:^id(NSInvocation *i) {
        return nil;
    }];

    [self.strategy start];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end

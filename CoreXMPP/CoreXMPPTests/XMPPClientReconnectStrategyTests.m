//
//  XMPPClientReconnectStrategyTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientReconnectStrategy.h"
#import "XMPPTestCase.h"

@interface XMPPClientReconnectStrategyTests : XMPPTestCase
@property (nonatomic, strong) XMPPClient *client;
@property (nonatomic, strong) XMPPClientReconnectStrategy *strategy;
@end

@implementation XMPPClientReconnectStrategyTests

- (void)setUp
{
    [super setUp];

    self.client = mock([XMPPClient class]);
    self.strategy = [[XMPPClientReconnectStrategy alloc] initWithClient:self.client];
}

#pragma mark Tests

- (void)testReconnectImmediately
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Connect Client"];
    [givenVoid([self.client connect]) willDo:^id(NSInvocation *invocation) {
        [expectation fulfill];
        return nil;
    }];

    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                        object:self.client
                                                      userInfo:@{}];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testTemporalReconnect
{
    [self expectationForNotification:XMPPClientReconnectStrategyDidChangeNotification
                              object:self.strategy
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 XMPPClientReconnectStrategy *strategy = notification.object;
                                 return strategy.type == XMPPClientReconnectStrategyTemporal;
                             }];

    NSDictionary *userInfo = @{ XMPPClientErrorKey : [NSError errorWithDomain:@"XMPPClientReconnectStrategyTests" code:12 userInfo:nil] };
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                        object:self.client
                                                      userInfo:userInfo];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatUnsignedInteger(self.strategy.type, equalToUnsignedInteger(XMPPClientReconnectStrategyTemporal));
    assertThat(self.strategy.nextConnectionAttempt, greaterThan([NSDate date]));
}

- (void)testReachabilityReconnect
{
    [given([self.client hostname]) willReturn:@"foo.example.com"];

    [self expectationForNotification:XMPPClientReconnectStrategyDidChangeNotification
                              object:self.strategy
                             handler:^BOOL(NSNotification *_Nonnull notification) {
                                 XMPPClientReconnectStrategy *strategy = notification.object;
                                 return strategy.type == XMPPClientReconnectStrategyNetworkReachability;
                             }];

    NSDictionary *userInfo = @{XMPPClientErrorKey : [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]};
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPClientDidDisconnectNotification
                                                        object:self.client
                                                      userInfo:userInfo];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatUnsignedInteger(self.strategy.type, equalToUnsignedInteger(XMPPClientReconnectStrategyNetworkReachability));
    assertThat(self.strategy.nextConnectionAttempt, nilValue());
}

@end
